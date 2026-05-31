//! Masters fertilizes API — `/api/v1/masters/fertilizes`

use crate::adapters::PassthroughTranslator;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{FertilizeSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::fertilize::dtos::{
    FertilizeCreateInput, FertilizeDestroyOutput, FertilizeDetailOutput, FertilizeUpdateInput,
};
use agrr_domain::fertilize::entities::FertilizeEntity;
use agrr_domain::fertilize::interactors::{
    FertilizeCreateInteractor, FertilizeDestroyInteractor, FertilizeDetailInteractor,
    FertilizeListInteractor, FertilizeUpdateInteractor,
};
use agrr_domain::fertilize::ports::{
    CreateFailure, DestroyFailure, DetailFailure, FertilizeCreateOutputPort,
    FertilizeDestroyOutputPort, FertilizeDetailOutputPort, FertilizeListOutputPort,
    FertilizeUpdateOutputPort, ListFailure, UpdateFailure,
};
use agrr_domain::shared::dtos::ReferencableListRow;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/masters/fertilizes", get(index).post(create))
        .route(
            "/api/v1/masters/fertilizes/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

fn fertilize_json(e: &FertilizeEntity) -> Value {
    json!({
        "id": e.id,
        "user_id": e.user_id,
        "name": e.name,
        "n": e.n,
        "p": e.p,
        "k": e.k,
        "description": e.description,
        "package_size": e.package_size,
        "is_reference": e.is_reference,
        "region": e.region,
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
impl FertilizeListOutputPort for ListPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<FertilizeEntity>>) {
        let payload: Vec<_> = rows.iter().map(|r| fertilize_json(&r.record)).collect();
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
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = ListPort(out.clone());
    let mut interactor = FertilizeListInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl FertilizeDetailOutputPort for DetailPort {
    fn on_success(&mut self, dto: FertilizeDetailOutput) {
        let d = dto.display_dto;
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(json!({
                "id": d.id,
                "name": d.name,
                "n": d.n,
                "p": d.p,
                "k": d.k,
                "description": d.description,
                "package_size": d.package_size,
                "is_reference": d.is_reference,
                "created_at": d.created_at,
                "updated_at": d.updated_at,
            })),
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
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = DetailPort(out.clone());
    let mut interactor = FertilizeDetailInteractor::new(
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

#[derive(Deserialize)]
struct FertilizeRequest {
    fertilize: FertilizeAttrs,
}

#[derive(Deserialize)]
struct FertilizeAttrs {
    name: Option<String>,
    n: Option<f64>,
    p: Option<f64>,
    k: Option<f64>,
    description: Option<String>,
    package_size: Option<f64>,
    region: Option<String>,
    is_reference: Option<bool>,
}

struct CreatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl FertilizeCreateOutputPort for CreatePort {
    fn on_success(&mut self, entity: FertilizeEntity) {
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::CREATED,
            Json(fertilize_json(&entity)),
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
    Json(payload): Json<FertilizeRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.fertilize;
    if body.name.as_deref().unwrap_or("").trim().is_empty() {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["name is required"]})),
        ));
    }
    let user_id = auth.0;
    let mut input = FertilizeCreateInput::new(body.name.clone().unwrap_or_default());
    input.n = body.n;
    input.p = body.p;
    input.k = body.k;
    input.description = body.description.clone();
    input.package_size = body.package_size;
    input.region = body.region.clone();
    input.is_reference = body.is_reference;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = CreatePort(out.clone());
    let mut interactor = FertilizeCreateInteractor::new(
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
impl FertilizeUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: FertilizeEntity) {
        *self.0.lock().unwrap() =
            Some(Ok((StatusCode::OK, Json(fertilize_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let (status, msg) = match failure {
            UpdateFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
            UpdateFailure::Fertilize(f) => (StatusCode::UNPROCESSABLE_ENTITY, f.message),
        };
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"errors": [msg]})))));
    }
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
    Json(payload): Json<FertilizeRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.fertilize;
    let user_id = auth.0;
    let input = FertilizeUpdateInput {
        fertilize_id: id,
        name: body.name.clone(),
        n: body.n,
        p: body.p,
        k: body.k,
        description: body.description.clone(),
        package_size: body.package_size,
        region: body.region.clone(),
        is_reference: body.is_reference,
    };
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = UpdatePort(out.clone());
    let mut interactor = FertilizeUpdateInteractor::new(
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
impl FertilizeDestroyOutputPort for DestroyPort {
    fn on_success(&mut self, output: FertilizeDestroyOutput) {
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
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = DestroyPort(out.clone());
    let mut interactor = FertilizeDestroyInteractor::new(
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
