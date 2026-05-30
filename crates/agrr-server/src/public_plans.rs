//! Public plan wizard + REST (`/api/v1/public_plans/*`) — P6 Wave C.

use crate::adapters::{NoopLogger, SystemClock};
use crate::add_crop_support::AddCropCropResolvePublic;
use crate::cultivation_plans_mutations::{
    run_add_crop, run_add_field, run_remove_field, run_adjust_plan, AddCropBody, AddFieldBody,
    AdjustBody,
};
use crate::optimization_job_chain::enqueue_private_plan_optimization_chain;
use crate::state::AppState;
use crate::workbench_payload;
use agrr_adapters_sqlite::{
    CropRowsAvailablePublicSqliteGateway, CropSqliteGateway, CultivationPlanFieldMutationSqliteGateway,
    CultivationPlanPlanCropSqliteGateway, CultivationPlanRestPlanReadDomainSqliteGateway,
    CultivationPlanRestPlanReadSqliteGateway, CultivationPlanSqliteGateway, FarmSqliteGateway,
    PublicPlanCropSqliteGateway, PublicPlanSqliteGateway,
};
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::cultivation_plan::dtos::{
    CultivationPlanInitCrop, CultivationPlanInitFarm, CultivationPlanRestAuth,
};
use agrr_domain::cultivation_plan::interactors::{
    CultivationPlanInitializeInteractor, RetrieveCultivationPlanInteractor,
};
use agrr_domain::cultivation_plan::ports::RetrieveCultivationPlanOutputPort;
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::farm::interactors::FarmListReferenceForRegionInteractor;
use agrr_domain::farm::ports::FarmListReferenceForRegionOutputPort;
use agrr_domain::public_plan::catalog::FarmSizeCatalog;
use agrr_domain::public_plan::dtos::{
    PublicPlanCreateInput, PublicPlanCreateNoCropsViewContext, PublicPlanCreateOutput,
};
use agrr_domain::public_plan::gateways::PublicPlanOptimizationJobChainGateway;
use agrr_domain::public_plan::interactors::{PublicPlanCreateInteractor, PublicPlanWizardCropsInteractor};
use agrr_domain::public_plan::ports::{
    PlanInitializerPort, PlanInitializerResult, PublicPlanCreateOutputPort,
    PublicPlanWizardCropsOutputPort,
};
use agrr_domain::public_plan::dtos::{PublicPlanCrop, PublicPlanFarm};
use agrr_domain::shared::dtos::Error;
use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{delete, get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashSet;
use time::Date;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/public_plans/farms", get(wizard_farms))
        .route("/api/v1/public_plans/farm_sizes", get(wizard_farm_sizes))
        .route("/api/v1/public_plans/crops", get(wizard_crops))
        .route("/api/v1/public_plans/plans", post(wizard_create_plan))
        .route(
            "/api/v1/public_plans/cultivation_plans/{id}/data",
            get(public_plan_data),
        )
        .route(
            "/api/v1/public_plans/cultivation_plans/{id}/adjust",
            post(public_adjust_plan),
        )
        .route(
            "/api/v1/public_plans/cultivation_plans/{id}/add_crop",
            post(public_add_crop),
        )
        .route(
            "/api/v1/public_plans/cultivation_plans/{id}/add_field",
            post(public_add_field),
        )
        .route(
            "/api/v1/public_plans/cultivation_plans/{id}/remove_field/{field_id}",
            delete(public_remove_field),
        )
        .route(
            "/api/v1/public_plans/entry_schedule/farms",
            get(entry_schedule_farms),
        )
}

async fn public_add_crop(
    State(state): State<AppState>,
    Path(plan_id): Path<i64>,
    Json(body): Json<AddCropBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool);
    let crop_resolve = AddCropCropResolvePublic::new(&crop_gateway);
    run_add_crop(
        &state,
        CultivationPlanRestAuth::public(),
        plan_id,
        body,
        crop_resolve,
    )
    .await
}

async fn public_add_field(
    State(state): State<AppState>,
    Path(plan_id): Path<i64>,
    Json(body): Json<AddFieldBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    run_add_field(
        &state,
        CultivationPlanRestAuth::public(),
        plan_id,
        body,
    )
    .await
}

async fn public_remove_field(
    State(state): State<AppState>,
    Path((plan_id, field_id)): Path<(i64, String)>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    run_remove_field(
        &state,
        CultivationPlanRestAuth::public(),
        plan_id,
        &field_id,
    )
    .await
}

#[derive(Deserialize)]
struct RegionQuery {
    region: Option<String>,
    locale: Option<String>,
}

#[derive(Deserialize)]
struct WizardCropsQuery {
    farm_id: i64,
}

#[derive(Deserialize)]
struct CreatePlanBody {
    farm_id: i64,
    farm_size_id: String,
    crop_ids: Option<Vec<i64>>,
}

fn region_from_query(q: &RegionQuery) -> String {
    if let Some(region) = q.region.as_deref().filter(|r| !r.is_empty()) {
        return region.to_string();
    }
    match q.locale.as_deref().unwrap_or("ja") {
        "ja" => "jp".into(),
        "us" => "us".into(),
        "in" => "in".into(),
        _ => "jp".into(),
    }
}

fn farm_json(farm: &FarmEntity) -> Value {
    json!({
        "id": farm.id,
        "name": farm.name,
        "latitude": farm.latitude,
        "longitude": farm.longitude,
        "region": farm.region,
    })
}

fn crop_json(crop: &CropEntity) -> Value {
    json!({
        "id": crop.id,
        "user_id": crop.user_id,
        "name": crop.name,
        "variety": crop.variety,
        "is_reference": crop.is_reference,
        "area_per_unit": crop.area_per_unit,
        "revenue_per_area": crop.revenue_per_area,
        "region": crop.region,
        "groups": crop.groups,
        "associated_pests": [],
        "created_at": crop.created_at,
        "updated_at": crop.updated_at,
    })
}

fn farm_size_catalog_json() -> Value {
    let sizes: Vec<Value> = FarmSizeCatalog::all()
        .iter()
        .map(|entry| {
            json!({
                "id": entry.id,
                "area_sqm": entry.area_sqm,
                "name": format!("public_plans.farm_sizes.{}.name", entry.id),
                "description": format!("public_plans.farm_sizes.{}.description", entry.id),
            })
        })
        .collect();
    json!(sizes)
}

fn new_session_id() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{nanos:032x}")
}

struct FarmsPresenter {
    body: Option<FarmsOutcome>,
}

enum FarmsOutcome {
    Success(Vec<FarmEntity>),
    Failure(String),
}

impl FarmListReferenceForRegionOutputPort for FarmsPresenter {
    fn on_success(&mut self, farms: Vec<FarmEntity>) {
        self.body = Some(FarmsOutcome::Success(farms));
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(FarmsOutcome::Failure(error.message));
    }
}

async fn wizard_farms(
    State(state): State<AppState>,
    Query(query): Query<RegionQuery>,
) -> impl IntoResponse {
    let region = region_from_query(&query);
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool);
    let logger = NoopLogger;
    let mut presenter = FarmsPresenter { body: None };
    let mut interactor =
        FarmListReferenceForRegionInteractor::new(&mut presenter, &gateway, &logger);
    if interactor.call(&region).is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "internal"})),
        );
    }
    match presenter.body {
        Some(FarmsOutcome::Success(farms)) => {
            let payload: Vec<Value> = farms.iter().map(farm_json).collect();
            (StatusCode::OK, Json(json!(payload)))
        }
        Some(FarmsOutcome::Failure(msg)) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": msg})),
        ),
        None => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        ),
    }
}

async fn wizard_farm_sizes() -> impl IntoResponse {
    (StatusCode::OK, Json(farm_size_catalog_json()))
}

struct WizardCropsPresenter {
    body: Option<WizardCropsOutcome>,
}

enum WizardCropsOutcome {
    Success(Vec<CropEntity>),
    FarmNotFound,
    Failure(String),
}

impl PublicPlanWizardCropsOutputPort for WizardCropsPresenter {
    fn on_success(&mut self, crops: Vec<CropEntity>) {
        self.body = Some(WizardCropsOutcome::Success(crops));
    }

    fn on_farm_not_found(&mut self) {
        self.body = Some(WizardCropsOutcome::FarmNotFound);
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(WizardCropsOutcome::Failure(error.message));
    }
}

async fn wizard_crops(
    State(state): State<AppState>,
    Query(query): Query<WizardCropsQuery>,
) -> impl IntoResponse {
    let pool = state.sqlite.clone();
    let farm_gateway = FarmSqliteGateway::new(pool.clone());
    let crop_gateway = CropSqliteGateway::new(pool);
    let logger = NoopLogger;
    let mut presenter = WizardCropsPresenter { body: None };
    let mut interactor = PublicPlanWizardCropsInteractor::new(
        &mut presenter,
        &farm_gateway,
        &crop_gateway,
        &logger,
    );
    if interactor.call(query.farm_id).is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "internal"})),
        );
    }
    match presenter.body {
        Some(WizardCropsOutcome::Success(crops)) => {
            let payload: Vec<Value> = crops.iter().map(crop_json).collect();
            (StatusCode::OK, Json(json!(payload)))
        }
        Some(WizardCropsOutcome::FarmNotFound) => (
            StatusCode::NOT_FOUND,
            Json(json!({
                "error": "api.errors.common.farm_not_found",
                "error_key": "api.errors.common.farm_not_found"
            })),
        ),
        Some(WizardCropsOutcome::Failure(msg)) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": msg})),
        ),
        None => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        ),
    }
}

struct SqlitePlanInitializer<'a> {
    plan_gateway: &'a CultivationPlanSqliteGateway,
    plan_crop_gateway: &'a CultivationPlanPlanCropSqliteGateway,
    field_gateway: &'a CultivationPlanFieldMutationSqliteGateway,
    crop_gateway: &'a CropSqliteGateway,
    clock: &'a SystemClock,
    logger: &'a NoopLogger,
}

impl PlanInitializerPort for SqlitePlanInitializer<'_> {
    fn call(
        &self,
        farm: &PublicPlanFarm,
        total_area: i64,
        crops: &[PublicPlanCrop],
        user_id: Option<i64>,
        session_id: &str,
        plan_type: &str,
        planning_start_date: Date,
        planning_end_date: Date,
    ) -> PlanInitializerResult {
        let init_crops: Result<Vec<CultivationPlanInitCrop>, String> = crops
            .iter()
            .map(|c| {
                let entity = self
                    .crop_gateway
                    .find_by_id(c.id)
                    .map_err(|e| e.to_string())?;
                Ok(CultivationPlanInitCrop {
                    id: entity.id,
                    name: entity.name,
                    variety: entity.variety,
                    area_per_unit: entity.area_per_unit.unwrap_or(0.0),
                    revenue_per_area: entity.revenue_per_area.unwrap_or(0.0),
                })
            })
            .collect();
        let init_crops = match init_crops {
            Ok(v) => v,
            Err(e) => return PlanInitializerResult::failure(vec![e]),
        };

        let mut interactor = CultivationPlanInitializeInteractor::new(
            CultivationPlanInitFarm {
                id: farm.id,
                name: farm.name.clone(),
            },
            total_area as f64,
            init_crops,
            self.plan_gateway,
            self.plan_crop_gateway,
            self.field_gateway,
            self.clock,
            self.logger,
        );
        if plan_type == "public" {
            interactor = interactor.with_public_planning(
                session_id,
                planning_start_date,
                planning_end_date,
            );
        } else {
            interactor = interactor.with_private_planning(
                user_id.unwrap_or(0),
                Some(session_id.to_string()),
                plan_type,
                None,
                None,
                Some(planning_start_date),
                Some(planning_end_date),
            );
        }

        match interactor.call() {
            Ok(result) if result.cultivation_plan.is_some() => {
                PlanInitializerResult::success(result.cultivation_plan.unwrap().id)
            }
            Ok(result) => PlanInitializerResult::failure(result.errors),
            Err(e) => PlanInitializerResult::failure(vec![e.to_string()]),
        }
    }
}

struct OptimizationJobChainAdapter<'a> {
    state: &'a AppState,
}

impl PublicPlanOptimizationJobChainGateway for OptimizationJobChainAdapter<'_> {
    fn enqueue_after_create(
        &self,
        cultivation_plan_id: i64,
        _caller_label: &str,
        _redirect_path: Option<&str>,
    ) {
        enqueue_private_plan_optimization_chain(
            cultivation_plan_id,
            "OptimizationChannel",
            self.state,
        );
    }
}

struct CreatePlanPresenter {
    body: Option<CreatePlanOutcome>,
}

enum CreatePlanOutcome {
    Success(i64),
    Failure { message: String, status: StatusCode },
}

impl PublicPlanCreateOutputPort for CreatePlanPresenter {
    fn on_success(&mut self, success_dto: PublicPlanCreateOutput) {
        self.body = Some(CreatePlanOutcome::Success(success_dto.plan_id));
    }

    fn on_failure(&mut self, failure_dto: Error) {
        let status = match failure_dto.message.as_str() {
            "Farm not found" => StatusCode::NOT_FOUND,
            "Invalid farm size" | "Invalid total area" | "No crops selected" => {
                StatusCode::UNPROCESSABLE_ENTITY
            }
            msg if msg.contains("Failed to create cultivation plan") => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        };
        self.body = Some(CreatePlanOutcome::Failure {
            message: failure_dto.message,
            status,
        });
    }

    fn on_no_crops_failure(&mut self, _view_context: PublicPlanCreateNoCropsViewContext) {
        self.on_failure(Error::new("No crops selected"));
    }
}

async fn wizard_create_plan(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreatePlanBody>,
) -> impl IntoResponse {
    let crop_ids: Vec<i64> = body
        .crop_ids
        .unwrap_or_default()
        .into_iter()
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    let session_id = headers
        .get("X-Public-Plan-Session")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string)
        .unwrap_or_else(new_session_id);

    let pool = state.sqlite.clone();
    let public_gateway = PublicPlanSqliteGateway::new(pool.clone());
    let crop_gateway = PublicPlanCropSqliteGateway::new(pool.clone());
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan_crop_gateway = CultivationPlanPlanCropSqliteGateway::new(pool.clone());
    let field_gateway = CultivationPlanFieldMutationSqliteGateway::new(pool.clone());
    let crop_read = CropSqliteGateway::new(pool);
    let clock = SystemClock;
    let logger = NoopLogger;
    let plan_initializer = SqlitePlanInitializer {
        plan_gateway: &plan_gateway,
        plan_crop_gateway: &plan_crop_gateway,
        field_gateway: &field_gateway,
        crop_gateway: &crop_read,
        clock: &clock,
        logger: &logger,
    };
    let job_chain = OptimizationJobChainAdapter { state: &state };

    let mut presenter = CreatePlanPresenter { body: None };
    let mut interactor = PublicPlanCreateInteractor::new(
        &mut presenter,
        &public_gateway,
        &crop_gateway,
        &plan_initializer,
        &logger,
        &clock,
        Some(&job_chain),
    );

    let input = PublicPlanCreateInput::new(
        body.farm_id,
        body.farm_size_id,
        crop_ids,
        session_id,
    );
    interactor.call(input);

    match presenter.body {
        Some(CreatePlanOutcome::Success(plan_id)) => {
            (StatusCode::OK, Json(json!({"plan_id": plan_id})))
        }
        Some(CreatePlanOutcome::Failure { message, status }) => {
            (status, Json(json!({"error": message})))
        }
        None => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        ),
    }
}

struct DataPresenter {
    body: Option<DataOutcome>,
}

enum DataOutcome {
    Success(Value),
    NotFound,
    Unexpected(String),
}

impl RetrieveCultivationPlanOutputPort for DataPresenter {
    fn on_success(
        &mut self,
        snapshot: agrr_domain::cultivation_plan::dtos::cultivation_plan_workbench::CultivationPlanWorkbenchSnapshot,
    ) {
        self.body = Some(DataOutcome::Success(workbench_payload::to_json_body(snapshot)));
    }

    fn on_not_found(&mut self) {
        self.body = Some(DataOutcome::NotFound);
    }

    fn on_unexpected(&mut self, message: &str) {
        self.body = Some(DataOutcome::Unexpected(message.to_string()));
    }
}

async fn public_plan_data(
    State(state): State<AppState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let rest_read = CultivationPlanRestPlanReadDomainSqliteGateway::new(
        CultivationPlanRestPlanReadSqliteGateway::new(pool.clone()),
    );
    let crop_rows = CropRowsAvailablePublicSqliteGateway::new(pool);
    let logger = NoopLogger;
    let mut presenter = DataPresenter { body: None };
    let auth = CultivationPlanRestAuth::public();
    let mut interactor = RetrieveCultivationPlanInteractor::new(
        &mut presenter,
        &plan_gateway,
        &rest_read,
        &crop_rows,
        &logger,
    );
    interactor.call_catch_all(&auth, plan_id).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": e.to_string()})),
        )
    })?;
    match presenter.body {
        Some(DataOutcome::Success(body)) => Ok(Json(body)),
        Some(DataOutcome::NotFound) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "not found"})),
        )),
        Some(DataOutcome::Unexpected(msg)) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}

async fn entry_schedule_farms(
    State(state): State<AppState>,
    Query(query): Query<RegionQuery>,
) -> impl IntoResponse {
    wizard_farms(State(state), Query(query)).await
}

async fn public_adjust_plan(
    State(state): State<AppState>,
    Path(plan_id): Path<i64>,
    Json(body): Json<AdjustBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    run_adjust_plan(
        &state,
        CultivationPlanRestAuth::public(),
        plan_id,
        body,
    )
    .await
}

