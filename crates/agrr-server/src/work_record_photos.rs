//! Work record photo upload, download, and delete APIs.

use std::collections::BTreeMap;
use std::sync::Arc;

use crate::adapters::SystemClock;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_gcs::WorkRecordPhotoGcsStore;
use agrr_adapters_sqlite::{CultivationPlanSqliteGateway, WorkRecordPhotoSqliteGateway};
use agrr_domain::work_record::dtos::WorkRecordPhotoRead;
use agrr_domain::work_record::gateways::{photo_row_to_read, WorkRecordPhotoGateway, WorkRecordPhotoObjectStoreGateway};
use agrr_domain::work_record::interactors::{
    WorkRecordPhotoDestroyInteractor, WorkRecordPhotoStalePendingCleanupInteractor,
    WorkRecordPhotoUploadCompleteInteractor, WorkRecordPhotoUploadInitInteractor,
};
use agrr_domain::work_record::policies::work_record_photo_policy::MAX_BYTE_SIZE;
use agrr_domain::work_record::ports::{
    WorkRecordPhotoDestroyOutputPort, WorkRecordPhotoUploadCompleteOutputPort,
    WorkRecordPhotoUploadInitOutputPort,
};
use agrr_domain::work_record::dtos::WorkRecordPhotoUploadInitOutput;
use axum::{
    body::Bytes,
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::{delete, post, put},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Map, Value};
use time::format_description::well_known::Iso8601;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/upload_init",
            post(upload_init),
        )
        .route(
            "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/{photo_id}/content",
            put(upload_content).get(download_content),
        )
        .route(
            "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/{photo_id}/upload_complete",
            post(upload_complete),
        )
        .route(
            "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/{photo_id}",
            delete(destroy_photo),
        )
}

#[derive(Deserialize)]
struct PhotoBody {
    photo: BTreeMap<String, Value>,
}

struct InitPresenter {
    body: Option<InitOutcome>,
}

struct CompletePresenter {
    body: Option<CompleteOutcome>,
}

struct DestroyPresenter {
    body: Option<DestroyOutcome>,
}

enum InitOutcome {
    Success(WorkRecordPhotoUploadInitOutput),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

enum CompleteOutcome {
    Success(WorkRecordPhotoRead),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

enum DestroyOutcome {
    Success,
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

impl WorkRecordPhotoUploadInitOutputPort for InitPresenter {
    fn on_success(&mut self, output: WorkRecordPhotoUploadInitOutput) {
        self.body = Some(InitOutcome::Success(output));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.body = Some(InitOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(InitOutcome::NotFound);
    }
}

impl WorkRecordPhotoUploadCompleteOutputPort for CompletePresenter {
    fn on_success(&mut self, photo: WorkRecordPhotoRead) {
        self.body = Some(CompleteOutcome::Success(photo));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.body = Some(CompleteOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(CompleteOutcome::NotFound);
    }
}

impl WorkRecordPhotoDestroyOutputPort for DestroyPresenter {
    fn on_success(&mut self) {
        self.body = Some(DestroyOutcome::Success);
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.body = Some(DestroyOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(DestroyOutcome::NotFound);
    }
}

pub fn photo_content_path(plan_id: i64, record_id: i64, photo_id: i64) -> String {
    format!("/api/v1/plans/{plan_id}/work_records/{record_id}/photos/{photo_id}/content")
}

pub fn photo_to_json(photo: WorkRecordPhotoRead) -> Value {
    json!({
        "id": photo.id,
        "work_record_id": photo.work_record_id,
        "position": photo.position,
        "content_type": photo.content_type,
        "byte_size": photo.byte_size,
        "url": photo.url,
        "created_at": photo.created_at.format(&Iso8601::DEFAULT).unwrap_or_default(),
    })
}

pub fn load_photos_json_for_records(
    photo_gateway: &WorkRecordPhotoSqliteGateway,
    plan_id: i64,
    record_ids: &[i64],
) -> Result<BTreeMap<i64, Vec<Value>>, Box<dyn std::error::Error + Send + Sync>> {
    let rows = photo_gateway.list_ready_for_plan(plan_id, record_ids)?;
    let mut grouped: BTreeMap<i64, Vec<Value>> = BTreeMap::new();
    for row in rows {
        let url = photo_content_path(plan_id, row.work_record_id, row.id);
        if let Some(read) = photo_row_to_read(row, url) {
            grouped
                .entry(read.work_record_id)
                .or_default()
                .push(photo_to_json(read));
        }
    }
    Ok(grouped)
}

fn unauthorized() -> (StatusCode, Json<Value>) {
    (
        StatusCode::UNAUTHORIZED,
        Json(json!({"errors": ["unauthorized"]})),
    )
}

fn not_found() -> (StatusCode, Json<Value>) {
    (
        StatusCode::NOT_FOUND,
        Json(json!({"errors": ["plans.errors.not_found"]})),
    )
}

fn record_invalid(errors: BTreeMap<String, Vec<String>>) -> (StatusCode, Json<Value>) {
    let mut map = Map::new();
    for (key, messages) in errors {
        map.insert(key, json!(messages));
    }
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        Json(json!({"errors": map})),
    )
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"errors": ["internal"]})),
    )
}

pub fn work_record_photo_store(
) -> Result<Arc<dyn WorkRecordPhotoObjectStoreGateway>, (StatusCode, Json<Value>)> {
    photo_store()
}

fn cleanup_stale_pending_photos(
    photo_gateway: &WorkRecordPhotoSqliteGateway,
    object_store: &dyn WorkRecordPhotoObjectStoreGateway,
) {
    let clock = SystemClock;
    let interactor =
        WorkRecordPhotoStalePendingCleanupInteractor::new(photo_gateway, object_store, &clock);
    let _ = interactor.call();
}

fn photo_store() -> Result<Arc<dyn WorkRecordPhotoObjectStoreGateway>, (StatusCode, Json<Value>)> {
    WorkRecordPhotoGcsStore::from_env()
        .map(|store| Arc::new(store) as Arc<dyn WorkRecordPhotoObjectStoreGateway>)
        .map_err(|_| internal_error())
}

fn parse_content_type(body: &BTreeMap<String, Value>) -> Option<String> {
    body.get("content_type")
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

fn parse_byte_size(body: &BTreeMap<String, Value>) -> Option<i64> {
    body.get("byte_size").and_then(|v| match v {
        Value::Number(n) => n.as_i64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    })
}

async fn upload_init(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id)): Path<(i64, i64)>,
    Json(body): Json<PhotoBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;
    let content_type = parse_content_type(&body.photo).ok_or_else(|| {
        record_invalid(BTreeMap::from([(
            "content_type".into(),
            vec!["plans.work_records.photos.errors.invalid_content_type".into()],
        )]))
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool);
    if let Ok(store) = photo_store() {
        cleanup_stale_pending_photos(&photo_gateway, store.as_ref());
    }
    let clock = SystemClock;
    let mut presenter = InitPresenter { body: None };
    let upload_url_builder = |plan: i64, record: i64, photo: i64| {
        photo_content_path(plan, record, photo)
    };

    let mut interactor = WorkRecordPhotoUploadInitInteractor::new(
        &mut presenter,
        &plan_gateway,
        &photo_gateway,
        &clock,
        &upload_url_builder,
    );
    interactor
        .call_rescuing(user_id, plan_id, record_id, &content_type)
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(InitOutcome::Success(output)) => Ok((
            StatusCode::CREATED,
            Json(json!({
                "photo": {
                    "id": output.photo_id,
                    "upload_url": output.upload_url,
                    "upload_method": output.upload_method,
                    "upload_expires_at": output.upload_expires_at.format(&Iso8601::DEFAULT).unwrap_or_default(),
                    "content_type": output.content_type,
                }
            })),
        )),
        Some(InitOutcome::NotFound) => Err(not_found()),
        Some(InitOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        None => Err(internal_error()),
    }
}

async fn upload_content(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id, photo_id)): Path<(i64, i64, i64)>,
    body: Bytes,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;
    if body.len() as i64 > MAX_BYTE_SIZE {
        return Err(record_invalid(BTreeMap::from([(
            "byte_size".into(),
            vec!["plans.work_records.photos.errors.invalid_byte_size".into()],
        )])));
    }

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool);
    if !agrr_domain::work_record::plan_access_allowed(&plan_gateway, plan_id, user_id) {
        return Err(not_found());
    }

    let row = photo_gateway
        .find_for_record(plan_id, record_id, photo_id)
        .map_err(|_| not_found())?;
    if row.status != agrr_domain::work_record::gateways::WorkRecordPhotoStatus::Pending {
        return Err(record_invalid(BTreeMap::from([(
            "status".into(),
            vec!["plans.work_records.photos.errors.already_completed".into()],
        )])));
    }

    let store = photo_store()?;
    let content_type = row
        .content_type
        .as_deref()
        .unwrap_or("image/jpeg");
    store
        .write_object(&row.storage_key, content_type, &body)
        .map_err(|_| internal_error())?;

    Ok(StatusCode::NO_CONTENT)
}

async fn upload_complete(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id, photo_id)): Path<(i64, i64, i64)>,
    Json(body): Json<PhotoBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;
    let byte_size = parse_byte_size(&body.photo).ok_or_else(|| {
        record_invalid(BTreeMap::from([(
            "byte_size".into(),
            vec!["plans.work_records.photos.errors.invalid_byte_size".into()],
        )]))
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool);
    let clock = SystemClock;
    let store = photo_store()?;
    let mut presenter = CompletePresenter { body: None };
    let read_url_builder =
        |plan: i64, record: i64, photo: i64| photo_content_path(plan, record, photo);

    let mut interactor = WorkRecordPhotoUploadCompleteInteractor::new(
        &mut presenter,
        &plan_gateway,
        &photo_gateway,
        store.as_ref(),
        &clock,
        &read_url_builder,
    );
    interactor
        .call_rescuing(user_id, plan_id, record_id, photo_id, byte_size)
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(CompleteOutcome::Success(photo)) => Ok(Json(json!({"photo": photo_to_json(photo)}))),
        Some(CompleteOutcome::NotFound) => Err(not_found()),
        Some(CompleteOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        None => Err(internal_error()),
    }
}

async fn download_content(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id, photo_id)): Path<(i64, i64, i64)>,
) -> Result<(StatusCode, HeaderMap, Vec<u8>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool);
    if !agrr_domain::work_record::plan_access_allowed(&plan_gateway, plan_id, user_id) {
        return Err(not_found());
    }

    let row = photo_gateway
        .find_for_record(plan_id, record_id, photo_id)
        .map_err(|_| not_found())?;
    if row.status != agrr_domain::work_record::gateways::WorkRecordPhotoStatus::Ready {
        return Err(not_found());
    }

    let store = photo_store()?;
    let bytes = store
        .read_object(&row.storage_key)
        .map_err(|_| internal_error())?
        .ok_or_else(|| not_found())?;

    let mut headers = HeaderMap::new();
    let content_type = row
        .content_type
        .as_deref()
        .unwrap_or("image/jpeg");
    if let Ok(value) = content_type.parse() {
        headers.insert(axum::http::header::CONTENT_TYPE, value);
    }

    Ok((StatusCode::OK, headers, bytes))
}

async fn destroy_photo(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id, photo_id)): Path<(i64, i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool);
    let store = photo_store()?;
    let mut presenter = DestroyPresenter { body: None };

    let mut interactor = WorkRecordPhotoDestroyInteractor::new(
        &mut presenter,
        &plan_gateway,
        &photo_gateway,
        store.as_ref(),
    );
    interactor
        .call_rescuing(user_id, plan_id, record_id, photo_id)
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(DestroyOutcome::Success) => Ok(StatusCode::NO_CONTENT),
        Some(DestroyOutcome::NotFound) => Err(not_found()),
        Some(DestroyOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        None => Err(internal_error()),
    }
}
