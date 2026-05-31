//! Masters pests API (`/api/v1/masters/pests`).

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{PestSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::pest::dtos::{PestCreateInput, PestDestroyOutput, PestUpdateInput};
use agrr_domain::pest::entities::PestEntity;
use agrr_domain::pest::interactors::{
    PestCreateInteractor, PestDestroyInteractor, PestDetailInteractor, PestListInteractor,
    PestUpdateInteractor,
};
use agrr_domain::pest::ports::{
    CreateFailure, DestroyFailure, DetailFailure, PestCreateOutputPort, PestDestroyOutputPort,
    PestDetailOutputPort, PestListOutputPort, PestUpdateOutputPort, UpdateFailure,
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
        .route("/api/v1/masters/pests", get(index).post(create))
        .route(
            "/api/v1/masters/pests/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

fn pest_entity_json(entity: &PestEntity) -> Value {
    json!({
        "id": entity.id,
        "user_id": entity.user_id,
        "name": entity.name,
        "name_scientific": entity.name_scientific,
        "family": entity.family,
        "order": entity.order,
        "description": entity.description,
        "occurrence_season": entity.occurrence_season,
        "region": entity.region,
        "is_reference": entity.is_reference,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
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
impl PestListOutputPort for ListPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<PestEntity>>) {
        let payload: Vec<_> = rows.iter().map(|r| pest_entity_json(&r.record)).collect();
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(json!(payload)))));
    }
    fn on_failure(&mut self, failure: agrr_domain::pest::ports::ListFailure) {
        let msg = match failure {
            agrr_domain::pest::ports::ListFailure::Error(e) => e.message,
        };
        *self.0.lock().unwrap() = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
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
    let gateway = PestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = ListPort(out.clone());
    let mut interactor =
        PestListInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PestDetailOutputPort for DetailPort {
    fn on_success(&mut self, output: agrr_domain::pest::dtos::PestDetailOutput) {
        // Rails `PestDetailApiPresenter` returns a flat pest entity (Angular `PestApiGateway.show`).
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(pest_entity_json(&output.pest)),
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
    let gateway = PestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = DetailPort(out.clone());
    let mut interactor = PestDetailInteractor::new(
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
struct PestBody {
    pest: PestAttrs,
}

#[derive(Deserialize)]
struct PestAttrs {
    name: Option<String>,
    name_scientific: Option<String>,
    family: Option<String>,
    order: Option<String>,
    description: Option<String>,
    occurrence_season: Option<String>,
    region: Option<String>,
    is_reference: Option<bool>,
}

struct CreatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PestCreateOutputPort for CreatePort {
    fn on_success(&mut self, entity: PestEntity) {
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::CREATED,
            Json(pest_entity_json(&entity)),
        )));
    }
    fn on_failure(&mut self, failure: CreateFailure) {
        let msg = match failure {
            CreateFailure::Error(e) => e.message,
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
    Json(payload): Json<PestBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    if payload.pest.name.as_deref().unwrap_or("").trim().is_empty() {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["name is required"]})),
        ));
    }
    let user_id = auth.0;
    let mut input = PestCreateInput::new(payload.pest.name.clone().unwrap());
    input.name_scientific = payload.pest.name_scientific.clone();
    input.family = payload.pest.family.clone();
    input.order = payload.pest.order.clone();
    input.description = payload.pest.description.clone();
    input.occurrence_season = payload.pest.occurrence_season.clone();
    input.region = payload.pest.region.clone();
    input.is_reference = payload.pest.is_reference;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PestSqliteGateway::new(pool.clone());
    let crop_gw = agrr_adapters_sqlite::PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gw = agrr_adapters_sqlite::CropPestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = CreatePort(out.clone());
    let mut interactor = PestCreateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &crop_gw,
        &crop_pest_gw,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct UpdatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PestUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: PestEntity) {
        *self.0.lock().unwrap() =
            Some(Ok((StatusCode::OK, Json(pest_entity_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let (status, msg) = match failure {
            UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, e.message),
            UpdateFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
            UpdateFailure::ReferenceFlagChange(_) => (
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
    Json(payload): Json<PestBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let input = PestUpdateInput {
        pest_id: id,
        name: payload.pest.name.clone(),
        name_scientific: payload.pest.name_scientific.clone(),
        family: payload.pest.family.clone(),
        order: payload.pest.order.clone(),
        description: payload.pest.description.clone(),
        occurrence_season: payload.pest.occurrence_season.clone(),
        region: payload.pest.region.clone(),
        is_reference: payload.pest.is_reference,
        pest_temperature_profile_attributes: None,
        pest_thermal_requirement_attributes: None,
        pest_control_methods_attributes: None,
        crop_ids: None,
    };
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = PestSqliteGateway::new(pool.clone());
    let crop_gw = agrr_adapters_sqlite::PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gw = agrr_adapters_sqlite::CropPestSqliteGateway::new(pool);
    let user_lookup = UserLookupSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let mut port = UpdatePort(out.clone());
    let mut interactor = PestUpdateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &crop_gw,
        &crop_pest_gw,
        &logger,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    take_response(&out)
}

struct DestroyPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PestDestroyOutputPort for DestroyPort {
    fn on_success(&mut self, output: PestDestroyOutput) {
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
    let gateway = PestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut port = DestroyPort(out.clone());
    let mut interactor = PestDestroyInteractor::new(
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

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::pest::entities::{PestEntity, PestEntityAttrs};

    #[test]
    fn pest_entity_json_exposes_name_at_top_level() {
        let entity = PestEntity::new(PestEntityAttrs {
            id: Some(1),
            user_id: Some(7),
            name: "テスト害虫".into(),
            name_scientific: Some("Testus pestus".into()),
            family: Some("テスト科".into()),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let json = pest_entity_json(&entity);
        assert_eq!(json["id"], 1);
        assert_eq!(json["name"], "テスト害虫");
        assert_eq!(json["name_scientific"], "Testus pestus");
        assert_eq!(json["family"], "テスト科");
        assert!(!json.as_object().unwrap().contains_key("pest"));
    }
}
