//! Private plans API (`/api/v1/plans`) — P6 Wave B.

use crate::adapters::{NoopLogger, PassthroughTranslator, SystemClock};
use crate::optimization_job_chain::enqueue_private_plan_weather_prep_chain;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CropSqliteGateway, CultivationPlanFieldMutationSqliteGateway,
    CultivationPlanPrivateReadSqliteGateway, CultivationPlanPrivateSnapshotReadSqliteGateway,
    CultivationPlanSqliteGateway, FarmSqliteGateway, FieldSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::shared::gateways::UserLookupGateway;
use agrr_domain::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, CultivationPlanInitFarm, CultivationPlanInitializeResult,
    PrivateCultivationPlanDetail, PrivatePlanIndexPlanRow, PrivatePlanInitializeFromSelectionFailure,
    PrivatePlanInitializeFromSelectionInput, PrivatePlanInitializeFromSelectionOutput,
    PrivatePlanMasterFieldSeed,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::gateways::CultivationPlanFieldMutationGateway;
use agrr_domain::cultivation_plan::interactors::{
    CultivationPlanDestroyInteractor, PrivateOwnedPlanDetailInteractor,
    PrivateOwnedPlansListInteractor, PrivatePlanInitializeFromSelectionInteractor,
};
use agrr_domain::cultivation_plan::ports::{
    CultivationPlanDestroyOutputPort, PrivateOwnedPlanDetailOutputPort,
    PrivateOwnedPlansListOutputPort, PrivatePlanInitializeCallablePort,
    PrivatePlanInitializeFromSelectionOutputPort, PrivatePlanOptimizationJobChainGateway,
    PrivatePlanSessionIdGeneratorPort,
};
use agrr_domain::shared::dtos::Error;
use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde::Serialize;
use serde_json::{json, Value};
use time::Date;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/plans", get(list_plans).post(create_plan))
        .route(
            "/api/v1/plans/{id}",
            get(show_plan).delete(destroy_plan),
        )
}
#[derive(Serialize)]
struct PlanListItem {
    id: i64,
    name: String,
    status: String,
}

#[derive(Serialize)]
struct PlanShowItem {
    id: i64,
    name: String,
    status: String,
}

struct ListPresenter {
    body: Option<Result<Vec<PlanListItem>, (String, u16)>>,
}

impl PrivateOwnedPlansListOutputPort for ListPresenter {
    fn on_success(&mut self, rows: Vec<PrivatePlanIndexPlanRow>) {
        let payload = rows
            .into_iter()
            .map(|row| PlanListItem {
                id: row.id,
                name: row.display_name,
                status: row.status,
            })
            .collect();
        self.body = Some(Ok(payload));
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(Err((error.message, 422)));
    }
}

struct ShowPresenter {
    body: Option<ShowOutcome>,
}

enum ShowOutcome {
    Success(PlanShowItem),
    NotFound,
    Failure(String),
}

impl PrivateOwnedPlanDetailOutputPort for ShowPresenter {
    fn on_success(&mut self, detail: PrivateCultivationPlanDetail) {
        self.body = Some(ShowOutcome::Success(PlanShowItem {
            id: detail.id,
            name: detail.display_name,
            status: detail.status,
        }));
    }

    fn on_not_found(&mut self) {
        self.body = Some(ShowOutcome::NotFound);
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(ShowOutcome::Failure(error.message));
    }
}

async fn list_plans(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Vec<PlanListItem>>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    let pool = state.sqlite.clone();
    let gateway = CultivationPlanPrivateReadSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let mut presenter = ListPresenter { body: None };

    let mut interactor = PrivateOwnedPlansListInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &logger,
        &user_lookup,
    );
    interactor.call().map_err(|_| {
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        )
    })?;

    match presenter.body {
        Some(Ok(items)) => Ok(Json(items)),
        Some(Err((msg, _))) => Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({"error": msg})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "no response"})),
        )),
    }
}

async fn show_plan(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<PlanShowItem>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    let pool = state.sqlite.clone();
    let snapshot_gateway = CultivationPlanPrivateSnapshotReadSqliteGateway::new(pool.clone());
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let mut presenter = ShowPresenter { body: None };

    let mut interactor = PrivateOwnedPlanDetailInteractor::new(
        &mut presenter,
        user_id,
        &snapshot_gateway,
        &plan_gateway,
        &crop_gateway,
        &translator,
        &logger,
        &user_lookup,
    );
    interactor.call_catch_all(id).map_err(|_| {
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        )
    })?;

    match presenter.body {
        Some(ShowOutcome::Success(item)) => Ok(Json(item)),
        Some(ShowOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "Plan not found"})),
        )),
        Some(ShowOutcome::Failure(msg)) => Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({"error": msg})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "no response"})),
        )),
    }
}

#[derive(Deserialize)]
struct CreatePlanBody {
    plan: CreatePlanParams,
}

#[derive(Deserialize)]
struct CreatePlanParams {
    farm_id: i64,
    plan_name: Option<String>,
}

struct CreatePresenter {
    body: Option<CreateOutcome>,
}

enum CreateOutcome {
    Success(i64),
    Failure { status: StatusCode, message: String },
}

impl PrivatePlanInitializeFromSelectionOutputPort for CreatePresenter {
    fn on_success(&mut self, dto: PrivatePlanInitializeFromSelectionOutput) {
        self.body = Some(CreateOutcome::Success(dto.id));
    }

    fn on_failure(&mut self, failure: PrivatePlanInitializeFromSelectionFailure) {
        let status = match failure.http_status {
            PrivatePlanInitializeFromSelectionFailure::HTTP_NOT_FOUND => StatusCode::NOT_FOUND,
            PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY => {
                StatusCode::UNPROCESSABLE_ENTITY
            }
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        };
        self.body = Some(CreateOutcome::Failure {
            status,
            message: failure.message,
        });
    }
}

struct PrivatePlanInitializer<'a> {
    plan_gateway: &'a CultivationPlanSqliteGateway,
    field_gateway: &'a CultivationPlanFieldMutationSqliteGateway,
}

impl PrivatePlanInitializeCallablePort for PrivatePlanInitializer<'_> {
    fn call(
        &self,
        farm: &CultivationPlanInitFarm,
        master_fields: &[PrivatePlanMasterFieldSeed],
        user_id: i64,
        session_id: &str,
        plan_name: &str,
        planning_start_date: Date,
        planning_end_date: Date,
    ) -> Result<CultivationPlanInitializeResult, Box<dyn std::error::Error + Send + Sync>> {
        let total_area: f64 = master_fields.iter().map(|field| field.area).sum();
        let create_attrs = CultivationPlanCreateAttrs {
            farm_id: farm.id,
            user_id: Some(user_id),
            total_area,
            plan_type: "private".to_string(),
            session_id: Some(session_id.to_string()),
            plan_year: None,
            plan_name: Some(plan_name.to_string()),
            planning_start_date: Some(planning_start_date),
            planning_end_date: Some(planning_end_date),
            status: None,
        };

        let fields = master_fields.to_vec();
        let plan = self.plan_gateway.within_transaction(|| {
            let plan_entity = self.plan_gateway.create(&create_attrs)?;
            for field in &fields {
                self.field_gateway.create_field(
                    plan_entity.id,
                    &field.name,
                    field.area,
                    field.daily_fixed_cost,
                )?;
            }
            self.plan_gateway.find_by_id(plan_entity.id)
        })?;

        Ok(CultivationPlanInitializeResult::success(plan))
    }
}

struct SessionIdGen;

impl PrivatePlanSessionIdGeneratorPort for SessionIdGen {
    fn generate(&self) -> String {
        format!(
            "{:032x}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        )
    }
}

struct JobChainAdapter<'a> {
    state: &'a AppState,
}

impl PrivatePlanOptimizationJobChainGateway for JobChainAdapter<'_> {
    fn enqueue_after_create(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        enqueue_private_plan_weather_prep_chain(
            cultivation_plan_id,
            "PlansOptimizationChannel",
            self.state,
        );
        Ok(())
    }
}

async fn create_plan(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<CreatePlanBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"error": "unauthorized"}))))?;
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let farm_gateway = FarmSqliteGateway::new(pool.clone());
    let field_read_gateway = FieldSqliteGateway::new(pool.clone());
    let field_mutation = CultivationPlanFieldMutationSqliteGateway::new(pool);
    let user_lookup = UserLookupSqliteGateway::new(state.sqlite.clone());
    let user = user_lookup.find(user_id);
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let clock = SystemClock;
    let mut presenter = CreatePresenter { body: None };
    let initializer = PrivatePlanInitializer {
        plan_gateway: &plan_gateway,
        field_gateway: &field_mutation,
    };
    let session_gen = SessionIdGen;
    let job_chain = JobChainAdapter { state: &state };
    let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
        &mut presenter,
        &plan_gateway,
        &farm_gateway,
        &field_read_gateway,
        &initializer,
        &logger,
        &translator,
        &clock,
        &session_gen,
        &job_chain,
    );
    let input = PrivatePlanInitializeFromSelectionInput {
        farm_id: body.plan.farm_id,
        user,
        plan_name: body.plan.plan_name,
    };
    interactor.call(&input).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    match presenter.body {
        Some(CreateOutcome::Success(id)) => Ok((StatusCode::CREATED, Json(json!({"id": id})))),
        Some(CreateOutcome::Failure { status, message }) => {
            Err((status, Json(json!({"error": message}))))
        }
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        )),
    }
}

struct DestroyPresenter {
    body: Option<DestroyOutcome>,
}

enum DestroyOutcome {
    Success(Value),
    Failure { status: StatusCode, message: String },
}

impl CultivationPlanDestroyOutputPort for DestroyPresenter {
    fn on_success(
        &mut self,
        dto: agrr_domain::cultivation_plan::dtos::CultivationPlanDestroyOutput,
    ) {
        let undo = dto.undo;
        let token = undo
            .get("undo_token")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        self.body = Some(DestroyOutcome::Success(json!({
            "undo_token": token,
            "undo_deadline": undo.get("undo_deadline"),
            "toast_message": undo.get("toast_message"),
            "undo_path": format!("/undo_deletion?undo_token={token}"),
            "auto_hide_after": undo.get("auto_hide_after").and_then(|v| v.as_i64()).unwrap_or(5),
            "resource": undo.get("resource"),
            "redirect_path": "/plans",
            "resource_dom_id": undo.get("resource_dom_id"),
        })));
    }

    fn on_failure(&mut self, error: Error) {
        let status = if error.message.contains("not_found") {
            StatusCode::NOT_FOUND
        } else {
            StatusCode::UNPROCESSABLE_ENTITY
        };
        self.body = Some(DestroyOutcome::Failure {
            status,
            message: "Plan not found".into(),
        });
    }
}

async fn destroy_plan(
    State(state): State<AppState>,
    jar: CookieJar,
    headers: HeaderMap,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"error": "unauthorized"}))))?;
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut presenter = DestroyPresenter { body: None };
    let mut interactor = CultivationPlanDestroyInteractor::new(
        &mut presenter,
        user_id,
        &plan_gateway,
        &translator,
        &user_lookup,
    );
    interactor.call(id).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    match presenter.body {
        Some(DestroyOutcome::Success(body)) => Ok(Json(body)),
        Some(DestroyOutcome::Failure { status, message }) => {
            Err((status, Json(json!({"error": message}))))
        }
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        )),
    }
}
