//! POST/DELETE cultivation plan REST mutations (add/remove field, adjust, add_crop) — P6 Wave B/F.

use std::collections::HashMap;

use crate::add_crop_support::{AddCropAdjustResultCollector, AddCropCropResolvePrivate};
use crate::adapters::{
    NoopOptimizationEventsGateway, PassthroughTranslator, StderrLogger, SystemClock,
};
use crate::adjust_weather_prediction::SqliteAdjustWeatherPredictionGateway;
use crate::plan_allocation_candidates::PlanAllocationCandidatesService;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_agrr::{
    PlanAllocationAdjustAgrrDaemonGateway, PlanAllocationCandidatesAgrrDaemonGateway,
};
use agrr_adapters_sqlite::{
    CropSqliteGateway, CultivationPlanFieldMutationSqliteGateway,
    CultivationPlanPlanCropSqliteGateway, CultivationPlanSqliteGateway,
    FieldCultivationSyncPlanReadSqliteGateway, FieldCultivationSyncSqliteGateway,
    PlanAllocationAdjustReadSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::{
    AddCropAdjustResult, CultivationPlanRestAuth, PlanAllocationAdjustFailure,
    PlanAllocationAdjustInput, PlanAllocationAdjustOutput,
};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustDebugDumpNullGateway;
use agrr_domain::cultivation_plan::interactors::{
    AddCropInteractor, AddFieldInteractor, PlanAllocationAdjustInteractor, RemoveFieldInteractor,
};
use agrr_domain::field_cultivation::interactors::FieldCultivationSyncInteractor;
use agrr_domain::cultivation_plan::ports::{
    AddCropCropResolveInputPort, AddCropOutputPort, AddFieldOutputPort,
    PlanAllocationAdjustInputPort, PlanAllocationAdjustOutputPort, RemoveFieldOutputPort,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{delete, post},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn mutation_routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/cultivation_plans/{id}/add_field",
            post(add_field),
        )
        .route(
            "/api/v1/plans/cultivation_plans/{id}/remove_field/{field_id}",
            delete(remove_field),
        )
        .route(
            "/api/v1/plans/cultivation_plans/{id}/adjust",
            post(adjust_plan),
        )
        .route(
            "/api/v1/plans/cultivation_plans/{id}/add_crop",
            post(add_crop),
        )
}

#[derive(Deserialize)]
pub(crate) struct AddCropBody {
    crop_id: serde_json::Value,
    /// Rails parity: optional; omitted when the client lets candidates pick any field.
    #[serde(default)]
    field_id: Option<serde_json::Value>,
    #[serde(default)]
    display_start_date: Option<String>,
    #[serde(default)]
    display_end_date: Option<String>,
}

struct AddCropPresenter {
    body: Option<AddCropOutcome>,
}

pub(crate) enum AddCropOutcome {
    Success(serde_json::Value),
    NotFound(&'static str),
    CropNotFound,
    PredictionIncomplete(String),
    NoCandidates,
    AdjustFailed(AddCropAdjustResult),
    RecordInvalid(String),
    Unexpected(String),
}

impl AddCropOutputPort for AddCropPresenter {
    fn on_success(&mut self, plan_crop_id: i64, plan_crop_display_name: &str) {
        self.body = Some(AddCropOutcome::Success(json!({
            "success": true,
            "message": "plans.messages.crop_added",
            "crop": {
                "id": plan_crop_id,
                "name": plan_crop_display_name
            }
        })));
    }

    fn on_not_found(&mut self) {
        self.body = Some(AddCropOutcome::NotFound("plans.errors.not_found"));
    }

    fn on_crop_not_found(&mut self) {
        self.body = Some(AddCropOutcome::CropNotFound);
    }

    fn on_prediction_incomplete(&mut self, technical_details: &str) {
        self.body = Some(AddCropOutcome::PredictionIncomplete(technical_details.to_string()));
    }

    fn on_no_candidates(&mut self) {
        self.body = Some(AddCropOutcome::NoCandidates);
    }

    fn on_adjust_failed(&mut self, adjust_result: &AddCropAdjustResult) {
        self.body = Some(AddCropOutcome::AdjustFailed(adjust_result.clone()));
    }

    fn on_record_invalid(&mut self, message: &str) {
        self.body = Some(AddCropOutcome::RecordInvalid(message.to_string()));
    }

    fn on_unexpected(&mut self, message: &str) {
        self.body = Some(AddCropOutcome::Unexpected(message.to_string()));
    }
}

pub(crate) fn map_add_crop_outcome(
    body: Option<AddCropOutcome>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    match body {
        Some(AddCropOutcome::Success(v)) => Ok(Json(v)),
        Some(AddCropOutcome::NotFound(msg)) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": msg})),
        )),
        Some(AddCropOutcome::CropNotFound) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "plans.errors.crop_not_found"})),
        )),
        Some(AddCropOutcome::PredictionIncomplete(details)) => Err((
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({
                "success": false,
                "message": "plans.errors.prediction_data_incomplete",
                "technical_details": details
            })),
        )),
        Some(AddCropOutcome::NoCandidates) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"success": false, "message": "plans.errors.no_candidates_found"})),
        )),
        Some(AddCropOutcome::AdjustFailed(adjust)) => {
            let status = adjust
                .http_status
                .and_then(|s| StatusCode::from_u16(s as u16).ok())
                .unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
            let technical_details = adjust.message.filter(|m| !m.is_empty());
            Err((
                status,
                Json(json!({
                    "success": false,
                    "message": "plans.gantt.adjust_failed",
                    "technical_details": technical_details
                })),
            ))
        }
        Some(AddCropOutcome::RecordInvalid(msg)) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"success": false, "message": msg})),
        )),
        Some(AddCropOutcome::Unexpected(msg)) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}

pub(crate) async fn run_add_crop<R>(
    state: &AppState,
    auth: CultivationPlanRestAuth,
    plan_id: i64,
    body: AddCropBody,
    crop_resolve: R,
) -> Result<Json<Value>, (StatusCode, Json<Value>)>
where
    R: AddCropCropResolveInputPort,
{
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan_crop_gateway = CultivationPlanPlanCropSqliteGateway::new(pool.clone());
    let read_gateway = PlanAllocationAdjustReadSqliteGateway::new(pool.clone());
    let candidates_agrr = PlanAllocationCandidatesAgrrDaemonGateway::from_env();
    let candidates_service = PlanAllocationCandidatesService::new(
        pool.clone(),
        &read_gateway,
        &candidates_agrr,
    );
    let adjust_sink = AddCropAdjustResultCollector::new();
    let mut adjust_output = adjust_sink.output_adapter();
    let adjust_gateway = PlanAllocationAdjustAgrrDaemonGateway::from_env();
    let weather_prediction_gateway = SqliteAdjustWeatherPredictionGateway::new(pool.clone());
    let events = NoopOptimizationEventsGateway;
    let debug_dump = PlanAllocationAdjustDebugDumpNullGateway;
    let logger = StderrLogger;
    let translator = PassthroughTranslator;
    let clock = SystemClock;
    let rule_seed = format!(
        "{:08x}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos() as u32
    );
    let sync_gateway = FieldCultivationSyncSqliteGateway::new(pool.clone());
    let sync_read = FieldCultivationSyncPlanReadSqliteGateway::new(pool.clone());
    let mut field_cultivation_sync =
        FieldCultivationSyncInteractor::new(&sync_gateway, &sync_read, &logger);

    let mut adjust_interactor = PlanAllocationAdjustInteractor::new(
        &mut adjust_output,
        &logger,
        &translator,
        &clock,
        &plan_gateway,
        &read_gateway,
        &adjust_gateway,
        &events,
        &debug_dump,
        &weather_prediction_gateway,
        &mut field_cultivation_sync,
        &rule_seed,
    );

    let crop_id = value_to_string(&body.crop_id);
    let field_id = body
        .field_id
        .as_ref()
        .map(value_to_string)
        .unwrap_or_default();
    let mut display_range = HashMap::new();
    if let Some(start) = body.display_start_date.as_deref() {
        display_range.insert("start_date".into(), json!(start));
    }
    if let Some(end) = body.display_end_date.as_deref() {
        display_range.insert("end_date".into(), json!(end));
    }
    let ui_filter_context = HashMap::new();

    let mut presenter = AddCropPresenter { body: None };
    let mut interactor = AddCropInteractor::new(
        &mut presenter,
        &logger,
        &mut adjust_interactor,
        &crop_resolve,
        &adjust_sink,
        &plan_gateway,
        &plan_crop_gateway,
        &candidates_service,
    );
    interactor
        .call(
            &auth,
            plan_id,
            &crop_id,
            &field_id,
            &display_range,
            &ui_filter_context,
        )
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"success": false, "message": e.to_string()})),
            )
        })?;
    map_add_crop_outcome(presenter.body)
}

async fn add_crop(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<AddCropBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"success": false, "message": "unauthorized"}))))?;
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let crop_resolve = AddCropCropResolvePrivate::new(&crop_gateway, user_id, &user_lookup);
    let auth = CultivationPlanRestAuth::private(user_id);
    run_add_crop(&state, auth, plan_id, body, crop_resolve).await
}

fn value_to_string(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Number(n) => n.to_string(),
        _ => value.to_string(),
    }
}

#[derive(Deserialize)]
pub(crate) struct AddFieldBody {
    field_name: String,
    field_area: f64,
    daily_fixed_cost: Option<f64>,
}

struct AddFieldPresenter {
    body: Option<AddFieldOutcome>,
}

pub(crate) enum AddFieldOutcome {
    Success(Value),
    NotFound,
    InvalidParams,
    MaxFields,
    RecordInvalid(String),
    Unexpected(String),
}

impl AddFieldOutputPort for AddFieldPresenter {
    fn on_success(&mut self, field_id: i64, name: &str, area: f64, total_area: f64) {
        self.body = Some(AddFieldOutcome::Success(json!({
            "success": true,
            "message": "plans.messages.field_added",
            "field": {
                "id": field_id,
                "field_id": field_id,
                "name": name,
                "area": area
            },
            "total_area": total_area
        })));
    }

    fn on_not_found(&mut self) {
        self.body = Some(AddFieldOutcome::NotFound);
    }

    fn on_invalid_field_params(&mut self) {
        self.body = Some(AddFieldOutcome::InvalidParams);
    }

    fn on_max_fields_limit(&mut self) {
        self.body = Some(AddFieldOutcome::MaxFields);
    }

    fn on_record_invalid(&mut self, message: &str) {
        self.body = Some(AddFieldOutcome::RecordInvalid(message.to_string()));
    }

    fn on_unexpected(&mut self, message: &str) {
        self.body = Some(AddFieldOutcome::Unexpected(message.to_string()));
    }
}

pub(crate) async fn run_add_field(
    state: &AppState,
    auth: CultivationPlanRestAuth,
    plan_id: i64,
    body: AddFieldBody,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let field_mutation = CultivationPlanFieldMutationSqliteGateway::new(pool);
    let events = NoopOptimizationEventsGateway;
    let logger = StderrLogger;
    let mut presenter = AddFieldPresenter { body: None };
    let mut interactor = AddFieldInteractor::new(
        &mut presenter,
        &plan_gateway,
        &field_mutation,
        &events,
        &logger,
    );
    interactor
        .call(
            &auth,
            plan_id,
            &body.field_name,
            Some(body.field_area),
            body.daily_fixed_cost,
        )
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"success": false, "message": e.to_string()})),
            )
        })?;
    map_add_field_outcome(presenter.body)
}

async fn add_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<AddFieldBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"success": false, "message": "unauthorized"}))))?;
    run_add_field(
        &state,
        CultivationPlanRestAuth::private(user_id),
        plan_id,
        body,
    )
    .await
}

struct RemoveFieldPresenter {
    body: Option<RemoveFieldOutcome>,
}

pub(crate) enum RemoveFieldOutcome {
    Success(Value),
    NotFound,
    FieldNotFound,
    RecordInvalid(String),
    Unexpected(String),
}

impl RemoveFieldOutputPort for RemoveFieldPresenter {
    fn on_success(&mut self, _field_id: i64, total_area: f64) {
        self.body = Some(RemoveFieldOutcome::Success(json!({
            "success": true,
            "message": "plans.messages.field_removed",
            "total_area": total_area
        })));
    }

    fn on_not_found(&mut self) {
        self.body = Some(RemoveFieldOutcome::NotFound);
    }

    fn on_field_not_found(&mut self) {
        self.body = Some(RemoveFieldOutcome::FieldNotFound);
    }

    fn on_cannot_remove_with_cultivations(&mut self) {
        self.body = Some(RemoveFieldOutcome::RecordInvalid(
            "plans.errors.cannot_remove_field_with_cultivations".into(),
        ));
    }

    fn on_cannot_remove_last_field(&mut self) {
        self.body = Some(RemoveFieldOutcome::RecordInvalid(
            "plans.errors.cannot_remove_last_field".into(),
        ));
    }

    fn on_record_invalid(&mut self, message: &str) {
        self.body = Some(RemoveFieldOutcome::RecordInvalid(message.to_string()));
    }

    fn on_unexpected(&mut self, message: &str) {
        self.body = Some(RemoveFieldOutcome::Unexpected(message.to_string()));
    }
}

pub(crate) async fn run_remove_field(
    state: &AppState,
    auth: CultivationPlanRestAuth,
    plan_id: i64,
    field_id: &str,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let field_mutation = CultivationPlanFieldMutationSqliteGateway::new(pool);
    let events = NoopOptimizationEventsGateway;
    let logger = StderrLogger;
    let mut presenter = RemoveFieldPresenter { body: None };
    let mut interactor = RemoveFieldInteractor::new(
        &mut presenter,
        &plan_gateway,
        &field_mutation,
        &events,
        &logger,
    );
    interactor
        .call(&auth, plan_id, field_id)
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"success": false, "message": e.to_string()})),
            )
        })?;
    map_remove_field_outcome(presenter.body)
}

async fn remove_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, field_id)): Path<(i64, String)>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"success": false, "message": "unauthorized"}))))?;
    run_remove_field(
        &state,
        CultivationPlanRestAuth::private(user_id),
        plan_id,
        &field_id,
    )
    .await
}

pub(crate) fn map_add_field_outcome(
    body: Option<AddFieldOutcome>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    match body {
        Some(AddFieldOutcome::Success(v)) => Ok(Json(v)),
        Some(AddFieldOutcome::NotFound) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "plans.errors.not_found"})),
        )),
        Some(AddFieldOutcome::InvalidParams) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"success": false, "message": "plans.errors.invalid_field_params"})),
        )),
        Some(AddFieldOutcome::MaxFields) => Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"success": false, "message": "plans.errors.max_fields_limit"})),
        )),
        Some(AddFieldOutcome::RecordInvalid(msg)) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"success": false, "message": msg})),
        )),
        Some(AddFieldOutcome::Unexpected(msg)) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}

#[derive(Deserialize)]
pub(crate) struct AdjustBody {
    #[serde(default)]
    moves: Vec<Value>,
}

struct AdjustPresenter {
    body: Option<AdjustOutcome>,
    adjust_result: Option<Value>,
}

enum AdjustOutcome {
    Success(Value),
    Failure(StatusCode, Value),
}

impl PlanAllocationAdjustOutputPort for AdjustPresenter {
    fn on_success(&mut self, output: PlanAllocationAdjustOutput) {
        self.adjust_result = output.adjust_result;
        let mut body = json!({
            "success": true,
            "message": output.message
        });
        if let Some(payload) = output.payload {
            if let Some(obj) = body.as_object_mut() {
                obj.insert("cultivation_plan".into(), payload);
            }
        }
        self.body = Some(AdjustOutcome::Success(body));
    }

    fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        let status = adjust_failure_status(&failure.kind);
        self.body = Some(AdjustOutcome::Failure(
            status,
            json!({ "success": false, "message": failure.message }),
        ));
    }
}

fn adjust_failure_status(kind: &str) -> StatusCode {
    match kind {
        PlanAllocationAdjustFailure::KIND_NO_WEATHER_LOCATION
        | PlanAllocationAdjustFailure::KIND_NOT_FOUND => StatusCode::NOT_FOUND,
        PlanAllocationAdjustFailure::KIND_INVALID_DATE
        | PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES => StatusCode::BAD_REQUEST,
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

fn normalize_moves(moves: Vec<Value>) -> Vec<Value> {
    moves
        .into_iter()
        .filter_map(|mut move_val| {
            let obj = move_val.as_object_mut()?;
            if let Some(id) = obj.get("allocation_id").and_then(|v| v.as_i64()) {
                obj.insert("allocation_id".into(), json!(id));
            } else if let Some(id) = obj.get("allocation_id").and_then(|v| v.as_u64()) {
                obj.insert("allocation_id".into(), json!(id as i64));
            }
            if let Some(fid) = obj.get("to_field_id") {
                if let Some(s) = fid.as_str() {
                    obj.insert("to_field_id".into(), json!(s));
                } else if let Some(n) = fid.as_i64() {
                    obj.insert("to_field_id".into(), json!(n.to_string()));
                }
            }
            Some(move_val)
        })
        .collect()
}

pub(crate) async fn run_adjust_plan(
    state: &AppState,
    auth: CultivationPlanRestAuth,
    plan_id: i64,
    body: AdjustBody,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let read_gateway = PlanAllocationAdjustReadSqliteGateway::new(pool.clone());
    let adjust_gateway = PlanAllocationAdjustAgrrDaemonGateway::from_env();
    let weather_prediction_gateway = SqliteAdjustWeatherPredictionGateway::new(pool.clone());
    let events = NoopOptimizationEventsGateway;
    let debug_dump = PlanAllocationAdjustDebugDumpNullGateway;
    let logger = StderrLogger;
    let translator = PassthroughTranslator;
    let clock = SystemClock;
    let rule_seed = format!(
        "{:08x}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos() as u32
    );
    let sync_gateway = FieldCultivationSyncSqliteGateway::new(pool.clone());
    let sync_read = FieldCultivationSyncPlanReadSqliteGateway::new(pool.clone());
    let mut field_cultivation_sync =
        FieldCultivationSyncInteractor::new(&sync_gateway, &sync_read, &logger);
    let mut presenter = AdjustPresenter {
        body: None,
        adjust_result: None,
    };
    let mut interactor = PlanAllocationAdjustInteractor::new(
        &mut presenter,
        &logger,
        &translator,
        &clock,
        &plan_gateway,
        &read_gateway,
        &adjust_gateway,
        &events,
        &debug_dump,
        &weather_prediction_gateway,
        &mut field_cultivation_sync,
        &rule_seed,
    );
    let moves = normalize_moves(body.moves);
    interactor
        .call(PlanAllocationAdjustInput {
            plan_id,
            moves,
            auth: Some(auth),
        })
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"success": false, "message": e.to_string()})),
            )
        })?;

    match presenter.body {
        Some(AdjustOutcome::Success(v)) => Ok(Json(v)),
        Some(AdjustOutcome::Failure(status, v)) => Err((status, Json(v))),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}

async fn adjust_plan(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<AdjustBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"success": false, "message": "unauthorized"}))))?;
    run_adjust_plan(
        &state,
        CultivationPlanRestAuth::private(user_id),
        plan_id,
        body,
    )
    .await
}

pub(crate) fn map_remove_field_outcome(
    body: Option<RemoveFieldOutcome>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    match body {
        Some(RemoveFieldOutcome::Success(v)) => Ok(Json(v)),
        Some(RemoveFieldOutcome::NotFound) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "plans.errors.not_found"})),
        )),
        Some(RemoveFieldOutcome::FieldNotFound) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "plans.errors.field_not_found"})),
        )),
        Some(RemoveFieldOutcome::RecordInvalid(msg)) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"success": false, "message": msg})),
        )),
        Some(RemoveFieldOutcome::Unexpected(msg)) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}

#[cfg(test)]
mod add_crop_body_tests {
    use super::AddCropBody;

    #[test]
    fn deserializes_without_field_id() {
        let body: AddCropBody = serde_json::from_str(r#"{"crop_id":1}"#).unwrap();
        assert!(body.field_id.is_none());
    }

    #[test]
    fn deserializes_with_field_id() {
        let body: AddCropBody = serde_json::from_str(r#"{"crop_id":1,"field_id":2}"#).unwrap();
        assert_eq!(body.field_id.as_ref().unwrap().as_i64(), Some(2));
    }
}
