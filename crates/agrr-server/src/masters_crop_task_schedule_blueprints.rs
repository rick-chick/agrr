//! Nested crop task schedule blueprints — `/api/v1/masters/crops/{crop_id}/task_schedule_blueprints`.

use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::{auth_user, internal_error};
use crate::state::AppState;
use agrr_adapters_agrr::{CropFertilizePlanAiQueryDaemonGateway, CropScheduleAiQueryDaemonGateway};
use agrr_adapters_sqlite::{
    AgriculturalTaskSqliteGateway, CropAgrrRequirementSqliteGateway,
    CropMastersTaskScheduleBlueprintSqliteGateway, CropSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::crop::dtos::{
    CropBlueprintRegenerateFailureReason, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateFailure, MastersCropTaskScheduleBlueprintCreateFailureReason,
    MastersCropTaskScheduleBlueprintCreateInput, MastersCropTaskScheduleBlueprintDestroyInput,
    MastersCropTaskScheduleBlueprintFailure, MastersCropTaskScheduleBlueprintFailureReason,
    MastersCropTaskScheduleBlueprintIndexInput, MastersCropTaskScheduleBlueprintRegenerateInput,
    MastersCropTaskScheduleBlueprintUpdateInput,
};
use agrr_domain::crop::interactors::crop_masters_task_schedule_blueprint_create_interactor::CropMastersTaskScheduleBlueprintCreateInteractor;
use agrr_domain::crop::interactors::crop_masters_task_schedule_blueprint_destroy_interactor::CropMastersTaskScheduleBlueprintDestroyInteractor;
use agrr_domain::crop::interactors::crop_masters_task_schedule_blueprint_index_interactor::CropMastersTaskScheduleBlueprintIndexInteractor;
use agrr_domain::crop::interactors::crop_masters_task_schedule_blueprint_regenerate_interactor::CropMastersTaskScheduleBlueprintRegenerateInteractor;
use agrr_domain::crop::interactors::crop_masters_task_schedule_blueprint_update_interactor::CropMastersTaskScheduleBlueprintUpdateInteractor;
use agrr_domain::crop::interactors::crop_regenerate_task_schedule_blueprints_interactor::CropRegenerateTaskScheduleBlueprintsInteractor;
use agrr_domain::crop::ports::{
    CropMastersTaskScheduleBlueprintCreateOutputPort,
    CropMastersTaskScheduleBlueprintDestroyOutputPort,
    CropMastersTaskScheduleBlueprintIndexOutputPort,
    CropMastersTaskScheduleBlueprintRegenerateOutputPort,
    CropMastersTaskScheduleBlueprintUpdateOutputPort,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, patch, post},
    Json, Router,
};
use rust_decimal::Decimal;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/crops/{crop_id}/task_schedule_blueprints",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/task_schedule_blueprints/regenerate",
            post(regenerate),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/task_schedule_blueprints/{id}",
            patch(update).delete(destroy),
        )
}

fn blueprint_json(b: &MastersCropTaskScheduleBlueprint) -> Value {
    json!({
        "id": b.id,
        "crop_id": b.crop_id,
        "agricultural_task_id": b.agricultural_task_id,
        "source_agricultural_task_id": b.source_agricultural_task_id,
        "stage_order": b.stage_order,
        "stage_name": b.stage_name,
        "gdd_trigger": decimal_to_json_f64(b.gdd_trigger),
        "gdd_tolerance": decimal_to_json_f64(b.gdd_tolerance),
        "task_type": b.task_type,
        "source": b.source,
        "priority": b.priority,
        "amount": decimal_to_json_f64(b.amount),
        "amount_unit": b.amount_unit,
        "description": b.description,
        "weather_dependency": b.weather_dependency,
        "time_per_sqm": decimal_to_json_f64(b.time_per_sqm),
        "name": b.name,
        "created_at": b.created_at,
        "updated_at": b.updated_at,
    })
}

fn decimal_to_json_f64(d: Option<Decimal>) -> Option<f64> {
    d.and_then(|v| v.to_string().parse().ok())
}

async fn index(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskScheduleBlueprintIndexOutputPort for Port {
        fn on_success(&mut self, rows: Vec<MastersCropTaskScheduleBlueprint>) {
            let json_rows: Vec<Value> = rows.iter().map(blueprint_json).collect();
            self.body = Some(Ok(Json(json!(json_rows))));
        }
        fn on_failure(&mut self, _: agrr_domain::crop::dtos::MastersCropTaskScheduleBlueprintFailure) {
            self.body = Some(Err((
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Crop not found"})),
            )));
        }
    }
    let mut port = Port { body: None };
    let mut interactor = CropMastersTaskScheduleBlueprintIndexInteractor::new(
        &mut port,
        &crop_gateway,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintIndexInput::new(user_id, crop_id))
        .map_err(|_| internal_error())?;
    match port.body {
        Some(Ok(json)) => Ok(json),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

#[derive(Deserialize)]
struct BlueprintCreateBody {
    agricultural_task_id: Option<i64>,
    stage_order: Option<i32>,
    stage_name: Option<String>,
    gdd_trigger: Option<f64>,
    task_type: Option<String>,
    description: Option<String>,
    priority: Option<i32>,
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Json(body): Json<BlueprintCreateBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let agricultural_task_gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        resp: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskScheduleBlueprintCreateOutputPort for Port {
        fn on_success(&mut self, row: MastersCropTaskScheduleBlueprint) {
            self.resp = Some(Ok((StatusCode::CREATED, Json(blueprint_json(&row)))));
        }
        fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintCreateFailure) {
            self.resp = Some(Err(create_failure_response(failure)));
        }
    }
    let mut port = Port { resp: None };
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut port,
        &crop_gateway,
        &agricultural_task_gateway,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintCreateInput {
            user_id,
            crop_id,
            agricultural_task_id: body.agricultural_task_id,
            stage_order: body.stage_order,
            stage_name: body.stage_name,
            gdd_trigger: body.gdd_trigger,
            task_type: body.task_type,
            description: body.description,
            priority: body.priority,
        })
        .map_err(|_| internal_error())?;
    port.resp.unwrap_or(Err(internal_error()))
}

async fn regenerate(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let agricultural_task_gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let agrr_req_gateway = CropAgrrRequirementSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let schedule_gateway = CropScheduleAiQueryDaemonGateway::from_env();
    let fertilize_gateway = CropFertilizePlanAiQueryDaemonGateway::from_env();
    let regenerate_core = CropRegenerateTaskScheduleBlueprintsInteractor::new(
        &crop_gateway,
        &blueprint_gateway,
        &agricultural_task_gateway,
        &agrr_req_gateway,
        &schedule_gateway,
        &fertilize_gateway,
    );
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskScheduleBlueprintRegenerateOutputPort for Port {
        fn on_success(&mut self, rows: Vec<MastersCropTaskScheduleBlueprint>) {
            let json_rows: Vec<Value> = rows.iter().map(blueprint_json).collect();
            self.body = Some(Ok(Json(json!(json_rows))));
        }
        fn on_failure(&mut self, failure: agrr_domain::crop::dtos::CropBlueprintRegenerateFailure) {
            self.body = Some(Err(regenerate_failure_response(failure)));
        }
    }
    let mut port = Port { body: None };
    let mut interactor = CropMastersTaskScheduleBlueprintRegenerateInteractor::new(
        &mut port,
        regenerate_core,
        &crop_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintRegenerateInput::new(
            user_id, crop_id,
        ))
        .map_err(|_| internal_error())?;
    match port.body {
        Some(Ok(json)) => Ok(json),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

#[derive(Deserialize)]
struct BlueprintBody {
    stage_order: Option<i64>,
    stage_name: Option<String>,
    gdd_trigger: Option<f64>,
    gdd_tolerance: Option<f64>,
    priority: Option<i64>,
    amount: Option<f64>,
    amount_unit: Option<String>,
    description: Option<String>,
    weather_dependency: Option<String>,
    time_per_sqm: Option<f64>,
    name: Option<String>,
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
    Json(body): Json<BlueprintBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    let attributes = json!({
        "stage_order": body.stage_order,
        "stage_name": body.stage_name,
        "gdd_trigger": body.gdd_trigger,
        "gdd_tolerance": body.gdd_tolerance,
        "priority": body.priority,
        "amount": body.amount,
        "amount_unit": body.amount_unit,
        "description": body.description,
        "weather_dependency": body.weather_dependency,
        "time_per_sqm": body.time_per_sqm,
        "name": body.name,
    });
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskScheduleBlueprintUpdateOutputPort for Port {
        fn on_success(&mut self, row: MastersCropTaskScheduleBlueprint) {
            self.body = Some(Ok(Json(blueprint_json(&row))));
        }
        fn on_failure(&mut self, failure: agrr_domain::crop::dtos::MastersCropTaskScheduleBlueprintFailure) {
            self.body = Some(Err(blueprint_failure_response(failure)));
        }
    }
    let mut port = Port { body: None };
    let mut interactor = CropMastersTaskScheduleBlueprintUpdateInteractor::new(
        &mut port,
        &crop_gateway,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintUpdateInput {
            user_id,
            crop_id,
            blueprint_id: id,
            attributes,
        })
        .map_err(|_| internal_error())?;
    match port.body {
        Some(Ok(json)) => Ok(json),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

async fn destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        status: Option<Result<StatusCode, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskScheduleBlueprintDestroyOutputPort for Port {
        fn on_success(&mut self) {
            self.status = Some(Ok(StatusCode::NO_CONTENT));
        }
        fn on_failure(&mut self, failure: agrr_domain::crop::dtos::MastersCropTaskScheduleBlueprintFailure) {
            self.status = Some(Err(blueprint_failure_response(failure)));
        }
    }
    let mut port = Port { status: None };
    let mut interactor = CropMastersTaskScheduleBlueprintDestroyInteractor::new(
        &mut port,
        &crop_gateway,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintDestroyInput {
            user_id,
            crop_id,
            blueprint_id: id,
        })
        .map_err(|_| internal_error())?;
    match port.status {
        Some(Ok(s)) => Ok(s),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

fn create_failure_response(
    failure: MastersCropTaskScheduleBlueprintCreateFailure,
) -> (StatusCode, Json<Value>) {
    use MastersCropTaskScheduleBlueprintCreateFailureReason::*;
    match failure.reason {
        MissingAgriculturalTaskId => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "agricultural_task_id is required", "error_code": "missing_agricultural_task_id"})),
        ),
        MissingGddTrigger => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "gdd_trigger is required", "error_code": "missing_gdd_trigger"})),
        ),
        InvalidStageOrder => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "stage_order is required", "error_code": "invalid_stage_order"})),
        ),
        CropNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Crop not found", "error_code": "crop_not_found"})),
        ),
        AgriculturalTaskNotFound => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({
                "error": "Agricultural task not found",
                "error_code": "agricultural_task_not_found"
            })),
        ),
        Duplicate => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({
                "error": "A task plan for this stage, task, and GDD timing already exists",
                "error_code": "duplicate_blueprint"
            })),
        ),
        ValidationFailed => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": failure.errors, "error_code": "validation_failed"})),
        ),
    }
}

fn regenerate_failure_response(
    failure: agrr_domain::crop::dtos::CropBlueprintRegenerateFailure,
) -> (StatusCode, Json<Value>) {
    use CropBlueprintRegenerateFailureReason::*;
    let (status, error_code) = match failure.reason {
        CropNotFound => (StatusCode::NOT_FOUND, "crop_not_found"),
        MissingBlueprints => (StatusCode::UNPROCESSABLE_ENTITY, "missing_blueprints"),
        MissingAgrrRequirement => (StatusCode::UNPROCESSABLE_ENTITY, "missing_agrr_requirement"),
        BlueprintRegenerationFromAgrrFailed => {
            (StatusCode::UNPROCESSABLE_ENTITY, "blueprint_generation_failed")
        }
        AiUnavailable => (StatusCode::SERVICE_UNAVAILABLE, "ai_unavailable"),
        AiExecutionFailed => (StatusCode::UNPROCESSABLE_ENTITY, "ai_execution_failed"),
    };
    (
        status,
        Json(json!({
            "error": failure.message,
            "error_code": error_code
        })),
    )
}

fn blueprint_failure_response(
    failure: agrr_domain::crop::dtos::MastersCropTaskScheduleBlueprintFailure,
) -> (StatusCode, Json<Value>) {
    use MastersCropTaskScheduleBlueprintFailureReason::*;
    match failure.reason {
        CropNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Crop not found"})),
        ),
        BlueprintNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Blueprint not found"})),
        ),
        Duplicate => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({
                "error": "A task plan for this stage, task, and GDD timing already exists",
                "error_code": "duplicate_blueprint"
            })),
        ),
    }
}
