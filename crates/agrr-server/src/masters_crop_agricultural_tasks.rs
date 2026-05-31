//! Nested crop agricultural task templates — `/api/v1/masters/crops/{crop_id}/agricultural_tasks`.

use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::{auth_user, internal_error, load_user_non_reference_crop};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    AgriculturalTaskSqliteGateway, CropMastersTaskTemplateSqliteGateway, CropSqliteGateway,
    UserLookupSqliteGateway,
};
use agrr_domain::crop::dtos::{
    MastersCropTaskTemplate, MastersCropTaskTemplateCreateFailure,
    MastersCropTaskTemplateCreateFailureReason, MastersCropTaskTemplateCreateInput,
    MastersCropTaskTemplateDestroyInput, MastersCropTaskTemplateIndexInput,
    MastersCropTaskTemplateMastersFailure, MastersCropTaskTemplateMastersFailureReason,
    MastersCropTaskTemplateUpdateInput,
};
use agrr_domain::crop::interactors::crop_masters_task_template_create_interactor::CropMastersTaskTemplateCreateInteractor;
use agrr_domain::crop::interactors::crop_masters_task_template_destroy_interactor::CropMastersTaskTemplateDestroyInteractor;
use agrr_domain::crop::interactors::crop_masters_task_template_index_interactor::CropMastersTaskTemplateIndexInteractor;
use agrr_domain::crop::interactors::crop_masters_task_template_update_interactor::CropMastersTaskTemplateUpdateInteractor;
use agrr_domain::crop::ports::{
    CropMastersTaskTemplateCreateOutputPort, CropMastersTaskTemplateDestroyOutputPort,
    CropMastersTaskTemplateIndexOutputPort, CropMastersTaskTemplateUpdateOutputPort,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use rust_decimal::Decimal;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/crops/{crop_id}/agricultural_tasks",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/agricultural_tasks/{id}",
            axum::routing::put(update)
                .patch(update)
                .delete(destroy),
        )
}

fn template_json(t: &MastersCropTaskTemplate) -> Value {
    let task = &t.agricultural_task;
    json!({
        "id": t.id,
        "crop_id": t.crop_id,
        "agricultural_task_id": t.agricultural_task_id,
        "name": t.name,
        "description": t.description,
        "time_per_sqm": decimal_to_json_f64(t.time_per_sqm),
        "weather_dependency": t.weather_dependency,
        "required_tools": t.required_tools,
        "skill_level": t.skill_level,
        "agricultural_task": {
            "id": task.id,
            "name": task.name,
            "description": task.description,
            "is_reference": task.is_reference,
        },
        "created_at": t.created_at,
        "updated_at": t.updated_at,
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
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskTemplateIndexOutputPort for Port {
        fn on_success(&mut self, rows: Vec<Value>) {
            self.body = Some(Ok(Json(json!(rows))));
        }
        fn on_failure(&mut self, _: MastersCropTaskTemplateMastersFailure) {
            self.body = Some(Err((
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Crop not found"})),
            )));
        }
    }
    let mut port = Port { body: None };
    let mut interactor =
        CropMastersTaskTemplateIndexInteractor::new(&mut port, &gateway, &user_lookup);
    interactor
        .call(MastersCropTaskTemplateIndexInput { user_id, crop_id })
        .map_err(|_| internal_error())?;
    match port.body {
        Some(Ok(json)) => Ok(json),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

#[derive(Deserialize)]
struct TemplateBody {
    agricultural_task_id: Option<i64>,
    name: Option<String>,
    description: Option<String>,
    time_per_sqm: Option<f64>,
    weather_dependency: Option<String>,
    required_tools: Option<Vec<String>>,
    skill_level: Option<String>,
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Json(body): Json<TemplateBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let mut input = MastersCropTaskTemplateCreateInput::new(user_id, crop_id, body.agricultural_task_id);
    input.name = body.name;
    input.description = body.description;
    input.time_per_sqm = body.time_per_sqm.and_then(Decimal::from_f64_retain);
    input.weather_dependency = body.weather_dependency;
    input.required_tools = body.required_tools;
    input.skill_level = body.skill_level;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let template_gateway = CropMastersTaskTemplateSqliteGateway::new(pool.clone());
    let task_gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        resp: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskTemplateCreateOutputPort for Port {
        fn on_success(&mut self, dto: MastersCropTaskTemplate) {
            self.resp = Some(Ok((StatusCode::CREATED, Json(template_json(&dto)))));
        }
        fn on_failure(&mut self, failure: MastersCropTaskTemplateCreateFailure) {
            self.resp = Some(Err(create_failure_response(failure)));
        }
    }
    let mut port = Port { resp: None };
    let mut interactor = CropMastersTaskTemplateCreateInteractor::new(
        &mut port,
        &gateway,
        &template_gateway,
        &user_lookup,
        &task_gateway,
    );
    interactor.call(input).map_err(|_| internal_error())?;
    port.resp.unwrap_or(Err(internal_error()))
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
    Json(body): Json<TemplateBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let attributes = json!({
        "name": body.name,
        "description": body.description,
        "time_per_sqm": body.time_per_sqm,
        "weather_dependency": body.weather_dependency,
        "required_tools": body.required_tools,
        "skill_level": body.skill_level,
    });
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskTemplateUpdateOutputPort for Port {
        fn on_success(&mut self, row: Value) {
            self.body = Some(Ok(Json(row)));
        }
        fn on_failure(&mut self, failure: MastersCropTaskTemplateMastersFailure) {
            self.body = Some(Err(masters_failure_response(failure)));
        }
    }
    let mut port = Port { body: None };
    let mut interactor =
        CropMastersTaskTemplateUpdateInteractor::new(&mut port, &gateway, &user_lookup);
    interactor
        .call(MastersCropTaskTemplateUpdateInput {
            user_id,
            crop_id,
            template_id: id,
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
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        status: Option<Result<StatusCode, (StatusCode, Json<Value>)>>,
    }
    impl CropMastersTaskTemplateDestroyOutputPort for Port {
        fn on_success(&mut self) {
            self.status = Some(Ok(StatusCode::NO_CONTENT));
        }
        fn on_failure(&mut self, failure: MastersCropTaskTemplateMastersFailure) {
            self.status = Some(Err(masters_failure_response(failure)));
        }
    }
    let mut port = Port { status: None };
    let mut interactor =
        CropMastersTaskTemplateDestroyInteractor::new(&mut port, &gateway, &user_lookup);
    interactor
        .call(MastersCropTaskTemplateDestroyInput {
            user_id,
            crop_id,
            template_id: id,
        })
        .map_err(|_| internal_error())?;
    match port.status {
        Some(Ok(s)) => Ok(s),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

fn create_failure_response(
    failure: MastersCropTaskTemplateCreateFailure,
) -> (StatusCode, Json<Value>) {
    use MastersCropTaskTemplateCreateFailureReason::*;
    match failure.reason {
        MissingAgriculturalTaskId => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "agricultural_task_id is required"})),
        ),
        CropNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Crop not found"})),
        ),
        AgriculturalTaskNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "AgriculturalTask not found"})),
        ),
        Forbidden => (
            StatusCode::FORBIDDEN,
            Json(json!({"error": "You do not have permission to associate this agricultural task"})),
        ),
        Duplicate => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "AgriculturalTask is already associated with this crop"})),
        ),
        ValidationFailed => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": failure.errors})),
        ),
    }
}

fn masters_failure_response(
    failure: MastersCropTaskTemplateMastersFailure,
) -> (StatusCode, Json<Value>) {
    use MastersCropTaskTemplateMastersFailureReason::*;
    match failure.reason {
        CropNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Crop not found"})),
        ),
        AssociationNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "AgriculturalTask association not found"})),
        ),
        ValidationFailed => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": failure.errors})),
        ),
    }
}
