//! Masters agricultural tasks API.

use crate::adapters::PassthroughTranslator;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{AgriculturalTaskSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::gateways::UserLookupGateway;
use agrr_domain::agricultural_task::dtos::{
    AgriculturalTaskCreateInput, AgriculturalTaskDestroyOutput, AgriculturalTaskDetailOutput,
    AgriculturalTaskListInput, AgriculturalTaskUpdateInput,
};
use agrr_domain::agricultural_task::entities::AgriculturalTaskEntity;
use agrr_domain::agricultural_task::interactors::{
    AgriculturalTaskCreateInteractor, AgriculturalTaskDestroyInteractor,
    AgriculturalTaskDetailInteractor, AgriculturalTaskListInteractor, AgriculturalTaskUpdateInteractor,
};
use agrr_domain::agricultural_task::ports::{
    AgriculturalTaskCreateOutputPort, AgriculturalTaskDestroyOutputPort,
    AgriculturalTaskDetailOutputPort, AgriculturalTaskListOutputPort,
    AgriculturalTaskUpdateOutputPort, DestroyFailure, DetailFailure, ListFailure, UpdateFailure,
};
use agrr_domain::shared::dtos::ReferencableListRow;
use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/agricultural_tasks",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/agricultural_tasks/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

#[derive(Deserialize)]
struct ListQuery {
    filter: Option<String>,
    q: Option<String>,
}

fn task_json(e: &AgriculturalTaskEntity) -> Value {
    json!({
        "id": e.id,
        "user_id": e.user_id,
        "name": e.name,
        "description": e.description,
        "time_per_sqm": e.time_per_sqm,
        "weather_dependency": e.weather_dependency,
        "required_tools": e.required_tools,
        "skill_level": e.skill_level,
        "region": e.region,
        "task_type": e.task_type,
        "is_reference": e.is_reference,
        "created_at": e.created_at,
        "updated_at": e.updated_at,
    })
}

fn take_response(
    out: &Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    match out.lock().unwrap().take() {
        Some(Ok(v)) => Ok(v),
        Some(Err(e)) => Err(e),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "internal"})),
        )),
    }
}

struct ListPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl AgriculturalTaskListOutputPort for ListPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<AgriculturalTaskEntity>>) {
        let payload: Vec<_> = rows.iter().map(|r| task_json(&r.record)).collect();
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(json!(payload)))));
    }
    fn on_failure(&mut self, failure: ListFailure) {
        let msg = match failure {
            ListFailure::Error(e) => e.message,
            ListFailure::Policy(_) => "forbidden".into(),
        };
        *self.0.lock().unwrap() = Some(Err((
            StatusCode::FORBIDDEN,
            Json(json!({"error": msg})),
        )));
    }
}

async fn index(
    State(state): State<AppState>,
    auth: MastersUserId,
    Query(q): Query<ListQuery>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let pool = state.sqlite.clone();
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let user = user_lookup.find(user_id);
    let input = AgriculturalTaskListInput::new(user.admin, q.filter.as_deref(), q.q.clone());
    let out = Arc::new(Mutex::new(None));
    let gateway = AgriculturalTaskSqliteGateway::new(pool);
    let mut port = ListPort(out.clone());
    let mut interactor =
        AgriculturalTaskListInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call(Some(input))
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl AgriculturalTaskDetailOutputPort for DetailPort {
    fn on_success(&mut self, dto: AgriculturalTaskDetailOutput) {
        // Rails `AgriculturalTaskDetailApiPresenter` returns flat task entity JSON.
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(task_json(&dto.task)),
        )));
    }
    fn on_failure(&mut self, failure: DetailFailure) {
        let (status, msg) = match failure {
            DetailFailure::Error(e) => (StatusCode::NOT_FOUND, e.message),
            DetailFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
        };
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"error": msg})))));
    }
}

async fn show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = DetailPort(out.clone());
    let mut interactor =
        AgriculturalTaskDetailInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call(id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

#[derive(Deserialize)]
struct TaskRequest {
    agricultural_task: TaskAttrs,
}

#[derive(Deserialize)]
struct TaskAttrs {
    name: Option<String>,
    description: Option<String>,
    time_per_sqm: Option<f64>,
    weather_dependency: Option<String>,
    skill_level: Option<String>,
    region: Option<String>,
    task_type: Option<String>,
    is_reference: Option<bool>,
}

struct CreatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl AgriculturalTaskCreateOutputPort for CreatePort {
    fn on_success(&mut self, entity: AgriculturalTaskEntity) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::CREATED, Json(task_json(&entity)))));
    }
    fn on_failure(&mut self, error: Error) {
        *self.0.lock().unwrap() = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [error.message]})),
        )));
    }
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Json(payload): Json<TaskRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.agricultural_task;
    let user_id = auth.0;
    let mut input = AgriculturalTaskCreateInput::new(body.name.clone().unwrap_or_default());
    input.description = body.description.clone();
    input.time_per_sqm = body.time_per_sqm;
    input.weather_dependency = body.weather_dependency.clone();
    input.skill_level = body.skill_level.clone();
    input.region = body.region.clone();
    input.task_type = body.task_type.clone();
    input.is_reference = body.is_reference;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = CreatePort(out.clone());
    let mut interactor = AgriculturalTaskCreateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct UpdatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl AgriculturalTaskUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: AgriculturalTaskEntity) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(task_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let msg = match failure {
            UpdateFailure::Error(e) => e.message,
            UpdateFailure::Policy(_) => "forbidden".into(),
            UpdateFailure::ReferenceFlag(_) => "reference flag change denied".into(),
        };
        *self.0.lock().unwrap() = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [msg]})),
        )));
    }
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
    Json(payload): Json<TaskRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.agricultural_task;
    let user_id = auth.0;
    let input = AgriculturalTaskUpdateInput {
        id,
        name: body.name.clone(),
        description: body.description.clone(),
        time_per_sqm: body.time_per_sqm,
        weather_dependency: body.weather_dependency.clone(),
        skill_level: body.skill_level.clone(),
        region: body.region.clone(),
        task_type: body.task_type.clone(),
        is_reference: body.is_reference,
        required_tools: None,
        selected_crop_ids: None,
    };
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = UpdatePort(out.clone());
    let mut interactor = AgriculturalTaskUpdateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DestroyPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl AgriculturalTaskDestroyOutputPort for DestroyPort {
    fn on_success(&mut self, output: AgriculturalTaskDestroyOutput) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(output.undo.raw))));
    }
    fn on_failure(&mut self, failure: DestroyFailure) {
        let (status, msg) = match failure {
            DestroyFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, e.message),
            DestroyFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
        };
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"error": msg})))));
    }
}

async fn destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    headers: HeaderMap,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut port = DestroyPort(out.clone());
    let mut interactor = AgriculturalTaskDestroyInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}
