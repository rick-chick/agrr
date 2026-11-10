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

fn pesticide_detail_json(dto: &PesticideDetailOutput) -> Value {
    let mut value = pesticide_json(&dto.pesticide);
    if let Some(obj) = value.as_object_mut() {
        obj.insert("crop_name".into(), json!(dto.crop_name));
        obj.insert("pest_name".into(), json!(dto.pest_name));
    }
    value
}

fn take_response(
    out: &Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    match out.lock().unwrap().take() {
        Some(Ok(v)) => Ok(v),
        Some(Err(e)) => Err(e),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
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
            Json(json!({"errors": [msg]})),
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PesticideDetailOutputPort for DetailPort {
    fn on_success(&mut self, dto: PesticideDetailOutput) {
        *self.0.lock().unwrap() = Some(Ok((
            StatusCode::OK,
            Json(pesticide_detail_json(&dto)),
        )));
    }
    fn on_failure(&mut self, failure: DetailFailure) {
        let (status, msg) = match failure {
            DetailFailure::Error(e) => (StatusCode::NOT_FOUND, e.message),
            DetailFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
        };
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"errors": [msg]})))));
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

struct UpdatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl PesticideUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: PesticideEntity) {
        *self.0.lock().unwrap() =
            Some(Ok((StatusCode::OK, Json(pesticide_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let (status, body) = update_failure(failure);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn update_failure(failure: UpdateFailure) -> (StatusCode, Value) {
    match failure {
        UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"errors": [e.message]})),
        UpdateFailure::Policy(_) => (StatusCode::FORBIDDEN, json!({"errors": ["forbidden"]})),
        UpdateFailure::ReferenceFlag(_) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"errors": ["reference flag change denied"]}),
        ),
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
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
        *self.0.lock().unwrap() = Some(Err((status, Json(json!({"errors": [msg]})))));
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::pesticide::dtos::PesticideDetailOutput;
    use agrr_domain::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use agrr_domain::shared::dtos::Error;
    use agrr_domain::shared::dtos::ReferenceFlagChangeDeniedFailure;
    use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;

    fn sample_entity() -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id: 3,
            user_id: Some(1),
            name: "サンプル".into(),
            active_ingredient: Some("有効成分".into()),
            description: None,
            crop_id: Some(10),
            pest_id: Some(20),
            region: Some("jp".into()),
            is_reference: false,
            created_at: "2020-01-01".into(),
            updated_at: "2020-01-02".into(),
        })
        .expect("valid entity")
    }

    fn valid_attrs() -> PesticideAttrs {
        PesticideAttrs {
            name: Some("農薬".into()),
            active_ingredient: None,
            description: None,
            crop_id: Some(json!("5")),
            pest_id: Some(json!(6)),
            region: None,
            is_reference: None,
        }
    }

    #[test]
    fn parse_optional_id_accepts_number_string_and_rejects_invalid() {
        assert_eq!(parse_optional_id(&Some(json!(42))), Some(42));
        assert_eq!(parse_optional_id(&Some(json!("  7 "))), Some(7));
        assert_eq!(parse_optional_id(&Some(json!(""))), None);
        assert_eq!(parse_optional_id(&Some(json!("not-a-number"))), None);
        assert_eq!(parse_optional_id(&Some(json!(null))), None);
        assert_eq!(parse_optional_id(&None), None);
        assert_eq!(parse_optional_id(&Some(json!([]))), None);
    }

    #[test]
    fn valid_pesticide_create_attrs_requires_positive_ids_and_non_empty_name() {
        assert!(valid_pesticide_create_attrs(&valid_attrs()));

        let missing_name = PesticideAttrs {
            name: Some("  ".into()),
            active_ingredient: None,
            description: None,
            crop_id: Some(json!("5")),
            pest_id: Some(json!(6)),
            region: None,
            is_reference: None,
        };
        assert!(!valid_pesticide_create_attrs(&missing_name));

        let zero_crop = PesticideAttrs {
            name: Some("農薬".into()),
            active_ingredient: None,
            description: None,
            crop_id: Some(json!(0)),
            pest_id: Some(json!(6)),
            region: None,
            is_reference: None,
        };
        assert!(!valid_pesticide_create_attrs(&zero_crop));
    }

    #[test]
    fn pesticide_detail_json_includes_related_names() {
        let entity = sample_entity();
        let dto = PesticideDetailOutput::new(
            entity,
            Some("トマト".into()),
            Some("アブラムシ".into()),
            None,
            None,
        );
        let value = pesticide_detail_json(&dto);
        assert_eq!(value["crop_name"], "トマト");
        assert_eq!(value["pest_name"], "アブラムシ");
        assert_eq!(value["name"], "サンプル");
    }

    #[test]
    fn update_failure_maps_reference_flag_to_422() {
        let (status, body) = update_failure(UpdateFailure::ReferenceFlag(
            ReferenceFlagChangeDeniedFailure::new("denied", 9),
        ));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "reference flag change denied");
    }

    #[test]
    fn update_failure_maps_policy_to_403() {
        let (status, body) = update_failure(UpdateFailure::Policy(PolicyPermissionDenied));
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "forbidden");
    }

    #[test]
    fn update_failure_maps_domain_error_to_422() {
        let (status, body) = update_failure(UpdateFailure::Error(Error::new("stale")));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "stale");
    }
}