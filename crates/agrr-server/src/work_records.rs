//! `POST/GET/PATCH/DELETE /api/v1/plans/{plan_id}/work_records` — work record CRUD (P4).

use std::collections::BTreeMap;

use crate::adapters::SystemClock;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use crate::work_record_photos::load_photos_json_for_records;
use agrr_adapters_sqlite::{CultivationPlanSqliteGateway, TaskScheduleItemLookupSqliteGateway, WorkRecordPhotoSqliteGateway, WorkRecordSqliteGateway};
use agrr_domain::work_record::dtos::{WorkRecordDestroyOutput, WorkRecordRead};
use agrr_domain::work_record::interactors::{
    WorkRecordCreateInteractor, WorkRecordDestroyInteractor, WorkRecordListInteractor,
    WorkRecordUpdateInteractor,
};
use agrr_domain::work_record::ports::{
    DestroyFailure, WorkRecordCreateOutputPort, WorkRecordDestroyOutputPort, WorkRecordListOutputPort,
    WorkRecordUpdateOutputPort,
};
use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    routing::{get, patch},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use rust_decimal::Decimal;
use serde::Deserialize;
use serde_json::{json, Map, Value};
use time::format_description::well_known::Iso8601;
use time::{Date, OffsetDateTime};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/{plan_id}/work_records",
            get(list_work_records).post(create_work_record),
        )
        .route(
            "/api/v1/plans/{plan_id}/work_records/{id}",
            patch(update_work_record).delete(destroy_work_record),
        )
}

#[derive(Deserialize)]
struct WorkRecordBody {
    work_record: BTreeMap<String, Value>,
}

type QueryParams = BTreeMap<String, String>;

struct CreatePresenter {
    body: Option<MutationOutcome<WorkRecordRead>>,
}

struct ListPresenter {
    body: Option<ListOutcome>,
}

struct UpdatePresenter {
    body: Option<MutationOutcome<WorkRecordRead>>,
}

struct DestroyPresenter {
    body: Option<DestroyOutcome>,
}

enum MutationOutcome<T> {
    Success(T),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

enum ListOutcome {
    Success(Vec<WorkRecordRead>),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

enum DestroyOutcome {
    Success(Value),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
    Failure(String),
}

impl WorkRecordCreateOutputPort for CreatePresenter {
    fn on_success(&mut self, record: WorkRecordRead) {
        self.body = Some(MutationOutcome::Success(record));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _fallback_message: &str,
    ) {
        self.body = Some(MutationOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(MutationOutcome::NotFound);
    }
}

impl WorkRecordListOutputPort for ListPresenter {
    fn on_success(&mut self, records: Vec<WorkRecordRead>) {
        self.body = Some(ListOutcome::Success(records));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _fallback_message: &str,
    ) {
        self.body = Some(ListOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(ListOutcome::NotFound);
    }
}

impl WorkRecordUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, record: WorkRecordRead) {
        self.body = Some(MutationOutcome::Success(record));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _fallback_message: &str,
    ) {
        self.body = Some(MutationOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(MutationOutcome::NotFound);
    }
}

impl WorkRecordDestroyOutputPort for DestroyPresenter {
    fn on_success(&mut self, output: WorkRecordDestroyOutput) {
        self.body = Some(DestroyOutcome::Success(output.undo));
    }

    fn on_failure(&mut self, error: DestroyFailure) {
        match error {
            DestroyFailure::Error(e) => {
                self.body = Some(DestroyOutcome::Failure(e.message));
            }
        }
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _fallback_message: &str,
    ) {
        self.body = Some(DestroyOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(DestroyOutcome::NotFound);
    }
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
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        Json(json!({"errors": errors_map_to_json(&errors)})),
    )
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"errors": ["internal"]})),
    )
}

fn errors_map_to_json(errors: &BTreeMap<String, Vec<String>>) -> Map<String, Value> {
    let mut map = Map::new();
    for (key, messages) in errors {
        map.insert(key.clone(), json!(messages));
    }
    map
}

fn format_date(date: Date) -> String {
    date.format(&Iso8601::DATE)
        .unwrap_or_else(|_| date.to_string())
}

fn format_datetime(dt: OffsetDateTime) -> String {
    dt.format(&Iso8601::DEFAULT)
        .unwrap_or_else(|_| dt.to_string())
}

fn format_decimal(amount: Option<Decimal>) -> Option<String> {
    amount.map(|d| d.to_string())
}

fn work_record_to_json(record: WorkRecordRead, photos: Vec<Value>) -> Value {
    json!({
        "id": record.id,
        "cultivation_plan_id": record.cultivation_plan_id,
        "field_cultivation_id": record.field_cultivation_id,
        "task_schedule_item_id": record.task_schedule_item_id,
        "agricultural_task_id": record.agricultural_task_id,
        "name": record.name,
        "task_type": record.task_type,
        "actual_date": format_date(record.actual_date),
        "amount": format_decimal(record.amount),
        "amount_unit": record.amount_unit,
        "time_spent_minutes": record.time_spent_minutes,
        "notes": record.notes,
        "created_at": format_datetime(record.created_at),
        "updated_at": format_datetime(record.updated_at),
        "task_schedule_item": record.task_schedule_item.map(|item| json!({
            "id": item.id,
            "name": item.name,
            "scheduled_date": item.scheduled_date.map(format_date),
        })),
        "photos": photos,
    })
}

fn map_mutation_outcome<T>(
    outcome: Option<MutationOutcome<T>>,
    success: impl FnOnce(T) -> Value,
    success_status: StatusCode,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    match outcome {
        Some(MutationOutcome::Success(record)) => Ok((success_status, Json(success(record)))),
        Some(MutationOutcome::NotFound) => Err(not_found()),
        Some(MutationOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        None => Err(internal_error()),
    }
}

async fn create_work_record(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<WorkRecordBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let work_record_gateway = WorkRecordSqliteGateway::new(pool.clone());
    let item_lookup = TaskScheduleItemLookupSqliteGateway::new(pool);
    let clock = SystemClock;
    let mut presenter = CreatePresenter { body: None };

    let mut interactor = WorkRecordCreateInteractor::new(
        &mut presenter,
        &plan_gateway,
        &work_record_gateway,
        &item_lookup,
        &clock,
    );
    interactor
        .call_rescuing(user_id, plan_id, &body.work_record)
        .map_err(|_| internal_error())?;

    map_mutation_outcome(presenter.body, |record| {
        let photos = vec![];
        json!({"work_record": work_record_to_json(record, photos)})
    }, StatusCode::CREATED)
}

async fn list_work_records(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Query(query): Query<QueryParams>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let work_record_gateway = WorkRecordSqliteGateway::new(pool);
    let mut presenter = ListPresenter { body: None };

    let mut interactor =
        WorkRecordListInteractor::new(&mut presenter, &plan_gateway, &work_record_gateway);
    interactor
        .call_rescuing(user_id, plan_id, &query)
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(ListOutcome::Success(records)) => {
            let record_ids: Vec<i64> = records.iter().map(|r| r.id).collect();
            let photo_gateway = WorkRecordPhotoSqliteGateway::new(state.sqlite.clone());
            let photos_by_record = load_photos_json_for_records(&photo_gateway, plan_id, &record_ids)
                .map_err(|_| internal_error())?;
            let items: Vec<Value> = records
                .into_iter()
                .map(|record| {
                    let photos = photos_by_record
                        .get(&record.id)
                        .cloned()
                        .unwrap_or_default();
                    work_record_to_json(record, photos)
                })
                .collect();
            Ok(Json(json!({"work_records": items})))
        }
        Some(ListOutcome::NotFound) => Err(not_found()),
        Some(ListOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        None => Err(internal_error()),
    }
}

async fn update_work_record(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, record_id)): Path<(i64, i64)>,
    Json(body): Json<WorkRecordBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let work_record_gateway = WorkRecordSqliteGateway::new(pool);
    let clock = SystemClock;
    let mut presenter = UpdatePresenter { body: None };

    let mut interactor = WorkRecordUpdateInteractor::new(
        &mut presenter,
        &plan_gateway,
        &work_record_gateway,
        &clock,
    );
    interactor
        .call_rescuing(user_id, plan_id, record_id, &body.work_record)
        .map_err(|_| internal_error())?;

    map_mutation_outcome(
        presenter.body,
        |record| {
            let photo_gateway = WorkRecordPhotoSqliteGateway::new(state.sqlite.clone());
            let photos = load_photos_json_for_records(&photo_gateway, plan_id, &[record.id])
                .ok()
                .and_then(|map| map.get(&record.id).cloned())
                .unwrap_or_default();
            json!({"work_record": work_record_to_json(record, photos)})
        },
        StatusCode::OK,
    )
    .map(|(_, json)| json)
}

async fn destroy_work_record(
    State(state): State<AppState>,
    jar: CookieJar,
    headers: HeaderMap,
    Path((plan_id, record_id)): Path<(i64, i64)>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|_| unauthorized())?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let work_record_gateway = WorkRecordSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut presenter = DestroyPresenter { body: None };

    let mut interactor = WorkRecordDestroyInteractor::new(
        &mut presenter,
        &plan_gateway,
        &work_record_gateway,
        &translator,
    );
    interactor
        .call_rescuing(user_id, plan_id, record_id)
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(DestroyOutcome::Success(undo)) => Ok(Json(undo)),
        Some(DestroyOutcome::NotFound) => Err(not_found()),
        Some(DestroyOutcome::RecordInvalid(errors)) => Err(record_invalid(errors)),
        Some(DestroyOutcome::Failure(message)) => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [message]})),
        )),
        None => Err(internal_error()),
    }
}
