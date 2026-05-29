//! Masters fields API — nested under farms and `/api/v1/masters/fields/:id`

use crate::adapters::PassthroughTranslator;
use crate::masters_json::field_to_json;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{FieldSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::field::dtos::{FieldCreateInput, FieldDetailInput, FieldUpdateInput};
use agrr_domain::field::entities::FieldEntity;
use agrr_domain::field::interactors::{
    FieldCreateInteractor, FieldDestroyInteractor, FieldDetailInteractor, FieldListInteractor,
    FieldUpdateInteractor,
};
use agrr_domain::field::ports::{
    CreateFailure, DestroyFailure, DetailFailure, FieldCreateOutputPort, FieldDestroyOutputPort,
    FieldDetailOutputPort, FieldListOutputPort, FieldUpdateOutputPort, ListFailure, UpdateFailure,
};
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/farms/{farm_id}/fields",
            get(list_fields).post(create_field),
        )
        .route(
            "/api/v1/masters/fields/{id}",
            get(show_field)
                .patch(update_field)
                .put(update_field)
                .delete(destroy_field),
        )
}

#[derive(Deserialize)]
struct FieldBody {
    field: FieldAttrs,
}

#[derive(Deserialize)]
struct FieldAttrs {
    name: Option<String>,
    area: Option<f64>,
    daily_fixed_cost: Option<f64>,
    region: Option<String>,
}

async fn list_fields(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(farm_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FieldSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = ListPresenter { body: None };
    let mut interactor =
        FieldListInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    interactor.call(farm_id).map_err(internal)?;

    match presenter.body {
        Some(Ok(fields)) => Ok(Json(json!(
            fields.iter().map(|f| field_to_json(f)).collect::<Vec<_>>()
        ))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn create_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(farm_id): Path<i64>,
    Json(payload): Json<FieldBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    if payload.field.name.as_deref().unwrap_or("").is_empty() {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["name is required"]})),
        ));
    }
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FieldSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = CreatePresenter { body: None };
    let mut interactor =
        FieldCreateInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    let mut input = FieldCreateInput::new(payload.field.name.clone().unwrap(), farm_id);
    input.area = payload.field.area;
    input.daily_fixed_cost = payload.field.daily_fixed_cost;
    input.region = payload.field.region.clone();
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok((StatusCode::CREATED, Json(field_to_json(&entity)))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn show_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FieldSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = DetailPresenter { body: None };
    let mut interactor =
        FieldDetailInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    let input = FieldDetailInput::new(id);
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(field_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn update_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(payload): Json<FieldBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FieldSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = UpdatePresenter { body: None };
    let mut interactor =
        FieldUpdateInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    let input = FieldUpdateInput {
        id,
        name: payload.field.name.clone(),
        area: payload.field.area,
        daily_fixed_cost: payload.field.daily_fixed_cost,
        region: payload.field.region.clone(),
    };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(field_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn destroy_field(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FieldSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = DestroyPresenter { body: None };
    let mut interactor = FieldDestroyInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor.call(id).map_err(internal)?;

    match presenter.body {
        Some(Ok(undo)) => Ok(Json(undo)),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

struct ListPresenter {
    body: Option<Result<Vec<FieldEntity>, (StatusCode, Value)>>,
}

impl FieldListOutputPort for ListPresenter {
    fn on_success(&mut self, list: agrr_domain::field::results::FarmFieldsList) {
        self.body = Some(Ok(list.fields));
    }

    fn on_failure(&mut self, error: ListFailure) {
        self.body = Some(Err(list_failure(error)));
    }
}

struct DetailPresenter {
    body: Option<Result<FieldEntity, (StatusCode, Value)>>,
}

impl FieldDetailOutputPort for DetailPresenter {
    fn on_success(&mut self, result: agrr_domain::field::results::FieldWithFarm) {
        self.body = Some(Ok(result.field));
    }

    fn on_failure(&mut self, error: DetailFailure) {
        self.body = Some(Err(detail_failure(error)));
    }
}

struct CreatePresenter {
    body: Option<Result<FieldEntity, (StatusCode, Value)>>,
}

impl FieldCreateOutputPort for CreatePresenter {
    fn on_success(&mut self, entity: FieldEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: CreateFailure) {
        self.body = Some(Err(create_failure(error)));
    }
}

struct UpdatePresenter {
    body: Option<Result<FieldEntity, (StatusCode, Value)>>,
}

impl FieldUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, entity: FieldEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: UpdateFailure) {
        self.body = Some(Err(update_failure(error)));
    }
}

struct DestroyPresenter {
    body: Option<Result<Value, (StatusCode, Value)>>,
}

impl FieldDestroyOutputPort for DestroyPresenter {
    fn on_success(&mut self, output: agrr_domain::field::dtos::FieldDestroyOutput) {
        let undo = &output.undo;
        let undo_token = undo.get("undo_token").and_then(|v| v.as_str()).unwrap_or("");
        let metadata = undo.get("metadata").cloned().unwrap_or(json!({}));
        let farm_id = metadata.get("farm_id").and_then(|v| v.as_i64()).unwrap_or(0);
        let origin = std::env::var("FRONTEND_URL")
            .unwrap_or_else(|_| "http://localhost:4200".into())
            .split(',')
            .next()
            .unwrap_or("http://localhost:4200")
            .trim()
            .to_string();
        self.body = Some(Ok(json!({
            "undo_token": undo_token,
            "undo_deadline": metadata.get("undo_deadline"),
            "toast_message": metadata.get("toast_message"),
            "undo_path": format!("/undo_deletion?undo_token={undo_token}"),
            "auto_hide_after": metadata.get("auto_hide_after").unwrap_or(&json!(5000)),
            "resource": metadata.get("resource_label"),
            "redirect_path": format!("{origin}/farms/{farm_id}"),
            "resource_dom_id": metadata.get("resource_dom_id"),
        })));
    }

    fn on_failure(&mut self, error: DestroyFailure) {
        self.body = Some(Err(destroy_failure(error)));
    }
}

fn list_failure(error: ListFailure) -> (StatusCode, Value) {
    match error {
        ListFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "fields.flash.no_permission"}),
        ),
        ListFailure::Error(e) => {
            let status = match e.message.as_str() {
                "Farm not found" => StatusCode::NOT_FOUND,
                "User not found" => StatusCode::UNAUTHORIZED,
                _ => StatusCode::UNPROCESSABLE_ENTITY,
            };
            (status, json!({"error": e.message}))
        }
    }
}

fn detail_failure(error: DetailFailure) -> (StatusCode, Value) {
    match error {
        DetailFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "fields.flash.no_permission"}),
        ),
        DetailFailure::FieldDetail(e) => {
            let status = if e.message == "Field not found" {
                StatusCode::NOT_FOUND
            } else {
                StatusCode::UNPROCESSABLE_ENTITY
            };
            (status, json!({"error": e.message}))
        }
    }
}

fn create_failure(error: CreateFailure) -> (StatusCode, Value) {
    match error {
        CreateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "fields.flash.no_permission"}),
        ),
        CreateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}

fn update_failure(error: UpdateFailure) -> (StatusCode, Value) {
    match error {
        UpdateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "fields.flash.no_permission"}),
        ),
        UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}

fn destroy_failure(error: DestroyFailure) -> (StatusCode, Value) {
    match error {
        DestroyFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "fields.flash.no_permission"}),
        ),
        DestroyFailure::Error(e) => {
            let status = if e.message == "Field not found" {
                StatusCode::NOT_FOUND
            } else {
                StatusCode::UNPROCESSABLE_ENTITY
            };
            (status, json!({"error": e.message}))
        }
    }
}

fn auth_user(state: &AppState, jar: &CookieJar) -> Result<i64, (StatusCode, Json<Value>)> {
    user_id_from_session(state, jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })
}

fn internal(_: Box<dyn std::error::Error + Send + Sync>) -> (StatusCode, Json<Value>) {
    internal_error()
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )
}
