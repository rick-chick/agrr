//! Masters pesticides API — `/api/v1/masters/pesticides`

use crate::adapters::PassthroughTranslator;
use crate::session_auth::user_id_from_session;
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
    http::StatusCode,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
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
    jar: CookieJar,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
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
        let usage = dto.usage_constraint_snapshot.as_ref().map(|u| {
            json!({
                "min_temperature": u.min_temperature,
                "max_temperature": u.max_temperature,
                "max_wind_speed_m_s": u.max_wind_speed_m_s,
                "max_application_count": u.max_application_count,
                "harvest_interval_days": u.harvest_interval_days,
                "other_constraints": u.other_constraints,
            })
        });
        let application = dto.application_detail_snapshot.as_ref().map(|a| {
            json!({
                "dilution_ratio": a.dilution_ratio,
                "amount_per_m2": a.amount_per_m2,
                "amount_unit": a.amount_unit,
                "application_method": a.application_method,
            })
        });
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(json!({
                "pesticide": pesticide_json(&dto.pesticide),
                "crop_name": dto.crop_name,
                "pest_name": dto.pest_name,
                "usage_constraint": usage,
                "application_detail": application,
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
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
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
struct PesticideBody {
    name: Option<String>,
    active_ingredient: Option<String>,
    description: Option<String>,
    crop_id: Option<i64>,
    pest_id: Option<i64>,
    region: Option<String>,
    is_reference: Option<bool>,
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
    jar: CookieJar,
    Json(body): Json<PesticideBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    let mut input = PesticideCreateInput::new(body.name.clone().unwrap_or_default());
    input.active_ingredient = body.active_ingredient.clone();
    input.description = body.description.clone();
    input.crop_id = body.crop_id;
    input.pest_id = body.pest_id;
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
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(body): Json<PesticideBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    let input = PesticideUpdateInput {
        pesticide_id: id,
        name: body.name.clone(),
        active_ingredient: body.active_ingredient.clone(),
        description: body.description.clone(),
        crop_id: body.crop_id,
        pest_id: body.pest_id,
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
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PesticideSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
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
