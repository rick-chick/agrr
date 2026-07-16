//! Nested crop stages under `/api/v1/masters/crops/:crop_id/crop_stages`.

use crate::masters_json::crop_stage_to_json;
use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::load_user_non_reference_crop;
use crate::state::AppState;
use agrr_adapters_sqlite::{CropSqliteGateway, CropStageSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::crop::dtos::{
    AuthorizedCropStageInCropContext, CropLoadAuthorizedCropStageInput, CropStageCreateInput,
    CropStageDeleteInput, CropStageListInput, CropStageReorderEntry, CropStageReorderInput,
    CropStageUpdateInput,
};
use agrr_domain::crop::interactors::crop_detail_interactor::CropDetailInteractor;
use agrr_domain::crop::interactors::crop_load_authorized_crop_stage_interactor::CropLoadAuthorizedCropStageInteractor;
use agrr_domain::crop::interactors::crop_stage_create_interactor::CropStageCreateInteractor;
use agrr_domain::crop::interactors::crop_stage_delete_interactor::CropStageDeleteInteractor;
use agrr_domain::crop::interactors::crop_stage_list_interactor::CropStageListInteractor;
use agrr_domain::crop::interactors::crop_stage_reorder_interactor::CropStageReorderInteractor;
use agrr_domain::crop::interactors::crop_stage_update_interactor::CropStageUpdateInteractor;
use agrr_domain::crop::ports::{
    CropDetailOutputPort, CropLoadedAuthorizationFailurePort, CropStageCreateOutputPort,
    CropStageDeleteOutputPort, CropStageListOutputPort, CropStageReorderOutputPort,
    CropStageUpdateOutputPort, DetailFailure,
};
use agrr_domain::crop::ports::{
    CropStageCreateFailure, CropStageDeleteFailure, CropStageReorderFailure,
    CropStageUpdateFailure,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, put},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/crops/{crop_id}/crop_stages/reorder",
            put(reorder),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/crop_stages",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/crop_stages/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

pub(crate) async fn ensure_crop_visible(
    state: &AppState,
    user_id: i64,
    crop_id: i64,
) -> Result<(), (StatusCode, Json<Value>)> {
    struct P {
        ok: bool,
    }
    impl CropDetailOutputPort for P {
        fn on_success(&mut self, _: agrr_domain::crop::dtos::CropDetailOutput) {
            self.ok = true;
        }
        fn on_failure(&mut self, _f: DetailFailure) {}
    }
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut p = P { ok: false };
    let mut interactor = CropDetailInteractor::new(&mut p, user_id, &gateway, &user_lookup);
    if interactor.call(crop_id).is_err() || !p.ok {
        return Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"}))));
    }
    Ok(())
}

pub(crate) async fn ensure_authorized_crop_stage(
    state: &AppState,
    user_id: i64,
    crop_id: i64,
    stage_id: i64,
    for_edit: bool,
) -> Result<AuthorizedCropStageInCropContext, (StatusCode, Json<Value>)> {
    struct FailurePort {
        failed: bool,
    }
    impl CropLoadedAuthorizationFailurePort for FailurePort {
        fn on_permission_denied(&mut self) {
            self.failed = true;
        }
        fn on_not_found(&mut self) {
            self.failed = true;
        }
    }

    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let stage_gateway = CropStageSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut failure_port = FailurePort { failed: false };
    let mut interactor = CropLoadAuthorizedCropStageInteractor::new(
        &mut failure_port,
        user_id,
        &crop_gateway,
        &stage_gateway,
        &user_lookup,
        for_edit,
    );
    let context = interactor
        .call(CropLoadAuthorizedCropStageInput::new(
            crop_id, stage_id, for_edit,
        ))
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;

    match context {
        Some(ctx) => Ok(ctx),
        None => Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"})))),
    }
}

async fn index(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        body: Option<Vec<Value>>,
    }
    impl CropStageListOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageListOutput) {
            self.body = Some(
                output
                    .stages
                    .iter()
                    .map(crop_stage_to_json)
                    .collect(),
            );
        }
        fn on_failure(&mut self, _: agrr_domain::crop::ports::CropStageListFailure) {}
    }
    let mut p = P { body: None };
    let mut interactor = CropStageListInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageListInput { crop_id })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(Json(json!(p.body.unwrap_or_default())))
}

async fn show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let context = ensure_authorized_crop_stage(&state, user_id, crop_id, id, false).await?;
    Ok(Json(crop_stage_to_json(&context.crop_stage_entity)))
}

#[derive(Deserialize)]
struct StageRequest {
    crop_stage: StageAttrs,
}

#[derive(Deserialize)]
struct StageAttrs {
    name: Option<String>,
    order: Option<i64>,
}

fn stage_payload_from_attrs(attrs: &StageAttrs) -> Result<Value, (StatusCode, Json<Value>)> {
    let name = attrs.name.as_deref().unwrap_or("").trim();
    if name.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        ));
    }
    let order = attrs.order.ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        )
    })?;
    Ok(json!({
        "name": name,
        "order": order,
    }))
}

fn stage_update_payload_from_attrs(attrs: &StageAttrs) -> Result<Value, (StatusCode, Json<Value>)> {
    let has_name = attrs.name.is_some();
    let has_order = attrs.order.is_some();
    if !has_name && !has_order {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        ));
    }
    if has_name && attrs.name.as_deref().unwrap_or("").trim().is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        ));
    }
    let mut payload = serde_json::Map::new();
    if let Some(name) = attrs.name.as_deref().map(str::trim).filter(|s| !s.is_empty()) {
        payload.insert("name".into(), json!(name));
    }
    if let Some(order) = attrs.order {
        payload.insert("order".into(), json!(order));
    }
    if payload.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        ));
    }
    Ok(Value::Object(payload))
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Json(body): Json<StageRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let payload = stage_payload_from_attrs(&body.crop_stage)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        resp: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
    }
    impl CropStageCreateOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageOutput) {
            self.resp = Some(Ok((
                StatusCode::CREATED,
                Json(crop_stage_to_json(&output.stage)),
            )));
        }
        fn on_failure(&mut self, _: CropStageCreateFailure) {
            self.resp = Some(Err((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({"errors": ["invalid"]})),
            )));
        }
    }
    let mut p = P { resp: None };
    let mut interactor = CropStageCreateInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageCreateInput::new(crop_id, payload))
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    p.resp.unwrap_or(Err((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )))
}

async fn reorder(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Json(body): Json<ReorderRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let entries = reorder_entries_from_body(&body)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        body: Option<Vec<Value>>,
    }
    impl CropStageReorderOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageListOutput) {
            self.body = Some(
                output
                    .stages
                    .iter()
                    .map(crop_stage_to_json)
                    .collect(),
            );
        }
        fn on_failure(&mut self, _: CropStageReorderFailure) {}
    }
    let mut p = P { body: None };
    let mut interactor = CropStageReorderInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageReorderInput { crop_id, entries })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    match p.body {
        Some(v) => Ok(Json(json!(v))),
        None => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["invalid"]})),
        )),
    }
}

#[derive(Deserialize)]
struct ReorderRequest {
    crop_stages: Vec<ReorderEntry>,
}

#[derive(Deserialize)]
struct ReorderEntry {
    id: i64,
    order: i64,
}

fn reorder_entries_from_body(
    body: &ReorderRequest,
) -> Result<Vec<CropStageReorderEntry>, (StatusCode, Json<Value>)> {
    if body.crop_stages.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "Invalid parameters"})),
        ));
    }
    Ok(body
        .crop_stages
        .iter()
        .map(|entry| CropStageReorderEntry {
            crop_stage_id: entry.id,
            order: entry.order,
        })
        .collect())
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
    Json(body): Json<StageRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, id, true).await?;
    let payload = stage_update_payload_from_attrs(&body.crop_stage)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        body: Option<Value>,
    }
    impl CropStageUpdateOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageOutput) {
            self.body = Some(crop_stage_to_json(&output.stage));
        }
        fn on_failure(&mut self, _: CropStageUpdateFailure) {}
    }
    let mut p = P { body: None };
    let mut interactor = CropStageUpdateInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageUpdateInput {
            crop_stage_id: id,
            payload,
        })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    match p.body {
        Some(v) => Ok(Json(v)),
        None => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["invalid"]})),
        )),
    }
}

async fn destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, id, true).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        ok: bool,
    }
    impl CropStageDeleteOutputPort for P {
        fn on_success(&mut self, _: agrr_domain::crop::dtos::CropStageDeleteOutput) {
            self.ok = true;
        }
        fn on_failure(&mut self, _: CropStageDeleteFailure) {}
    }
    let mut p = P { ok: false };
    let mut interactor = CropStageDeleteInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageDeleteInput { crop_stage_id: id })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    if p.ok {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"}))))
    }
}
