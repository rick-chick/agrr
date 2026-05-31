//! Masters pesticides API — `/api/v1/masters/pesticides`

use crate::adapters::PassthroughTranslator;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{PesticideSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::pesticide::dtos::{
    PesticideCreateInput, PesticideDestroyOutput, PesticideDetailOutput, PesticideUpdateInput,
};
use agrr_domain::pesticide::entities::PesticideEntity;
use agrr_domain::pesticide::interactors::{
    PesticideCreateInteractor, PesticideDestroyInteractor, PesticideDetailInteractor,
    PesticideListInteractor, PesticideUpdateInteractor,
};
use agrr_domain::pesticide::ports::{
    CreateFailure, DestroyFailure, DetailFailure, PesticideCreateOutputPort,
    PesticideDestroyOutputPort, PesticideDetailOutputPort, PesticideListOutputPort,
    PesticideUpdateOutputPort, ListFailure, UpdateFailure,
};
use agrr_domain::shared::dtos::ReferencableListRow;
use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/masters/pesticides", get(index).post(create))
        .route(
            "/api/v1/masters/pesticides/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

fn pesticide_json(e: &PesticideEntity) -> Value {
    json!({
        "id": e.id,
        "user_id": e.user_id,
        "name": e.name,
        "active_ingredient": e.active_ingredient,
        "description": e.description,
        "crop_id": e.crop_id,
        "pest_id": e.pest_id,
        "region": e.region,
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
impl PesticideListOutputPort for ListPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<PesticideEntity>>) {
        let payload: Vec<_> = rows.iter().map(|r| pesticide_json(&r.record)).collect();
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
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = ListPort(out.clone());
    let mut interactor = PesticideListInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PesticideDetailOutputPort for DetailPort {
    fn on_success(&mut self, dto: PesticideDetailOutput) {
        // Rails `PesticideDetailApiPresenter` returns flat pesticide entity JSON.
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(pesticide_json(&dto.pesticide)),
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
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = DetailPort(out.clone());
    let mut interactor =
        PesticideDetailInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call(id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

#[derive(Deserialize)]
struct PesticideRequest {
    pesticide: PesticideAttrs,
}

#[derive(Deserialize)]
struct PesticideAttrs {
    name: Option<String>,
    active_ingredient: Option<String>,
    description: Option<String>,
    /// Angular `<select [value]>` may send JSON strings; parse in `parse_optional_id`.
    crop_id: Option<serde_json::Value>,
    pest_id: Option<serde_json::Value>,
    region: Option<String>,
    is_reference: Option<bool>,
}

const PESTICIDE_REQUIRED_FIELDS_MSG: &str = "name, crop_id, pest_id are required";

fn parse_optional_id(value: &Option<serde_json::Value>) -> Option<i64> {
    match value {
        None | Some(serde_json::Value::Null) => None,
        Some(serde_json::Value::Number(n)) => n.as_i64(),
        Some(serde_json::Value::String(s)) => {
            let s = s.trim();
            if s.is_empty() {
                None
            } else {
                s.parse().ok()
            }
        }
        _ => None,
    }
}

fn valid_pesticide_create_attrs(attrs: &PesticideAttrs) -> bool {
    let name_ok = attrs
        .name
        .as_deref()
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false);
    let crop_ok = parse_optional_id(&attrs.crop_id).is_some_and(|id| id > 0);
    let pest_ok = parse_optional_id(&attrs.pest_id).is_some_and(|id| id > 0);
    name_ok && crop_ok && pest_ok
}

struct CreatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PesticideCreateOutputPort for CreatePort {
    fn on_success(&mut self, entity: PesticideEntity) {
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::CREATED,
            Json(pesticide_json(&entity)),
        )));
    }
    fn on_failure(&mut self, failure: CreateFailure) {
        let msg = match failure {
            CreateFailure::Error(e) => e.message,
            CreateFailure::Policy(_) => "forbidden".into(),
        };
        *self.0.lock().unwrap() = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [msg]})),
        )));
    }
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Json(payload): Json<PesticideRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.pesticide;
    if !valid_pesticide_create_attrs(&body) {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [PESTICIDE_REQUIRED_FIELDS_MSG]})),
        ));
    }
    let user_id = auth.0;
    let mut input = PesticideCreateInput::new(body.name.clone().unwrap_or_default());
    input.active_ingredient = body.active_ingredient.clone();
    input.description = body.description.clone();
    input.crop_id = parse_optional_id(&body.crop_id);
    input.pest_id = parse_optional_id(&body.pest_id);
    input.region = body.region.clone();
    input.is_reference = body.is_reference;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = CreatePort(out.clone());
    let mut interactor = PesticideCreateInteractor::new(
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
impl PesticideUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: PesticideEntity) {
        *self.0.lock().unwrap() =
            Some(Ok((StatusCode::OK, Json(pesticide_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let (status, msg) = match failure {
            UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, e.message),
            UpdateFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
            UpdateFailure::ReferenceFlag(_) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "reference flag change denied".into(),
            ),
        };
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"errors": [msg]})))));
    }
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
    Json(payload): Json<PesticideRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.pesticide;
    let user_id = auth.0;
    let input = PesticideUpdateInput {
        pesticide_id: id,
        name: body.name.clone(),
        active_ingredient: body.active_ingredient.clone(),
        description: body.description.clone(),
        crop_id: parse_optional_id(&body.crop_id),
        pest_id: parse_optional_id(&body.pest_id),
        region: body.region.clone(),
        is_reference: body.is_reference,
    };
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = UpdatePort(out.clone());
    let mut interactor = PesticideUpdateInteractor::new(
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
impl PesticideDestroyOutputPort for DestroyPort {
    fn on_success(&mut self, output: PesticideDestroyOutput) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(output.undo))));
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
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut port = DestroyPort(out.clone());
    let mut interactor = PesticideDestroyInteractor::new(
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
