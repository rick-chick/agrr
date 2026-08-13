//! `GET /api/v1/plans/:id/task_schedule` — private plan task timeline (P6).
//! `POST .../task_schedule/items` — manual item create.
//! `PATCH .../task_schedule/items/:item_id` — item update (scheduled date etc.).
//! `PATCH .../task_schedule/items/:item_id/skip|unskip` — skip / unskip (P5).

use std::collections::BTreeMap;

use crate::adapters::SystemClock;
use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use crate::task_schedule_timeline_json::{to_json_body, TaskScheduleQuery};
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    TaskScheduleItemMutationSqliteGateway, UserLookupSqliteGateway,
    UserOrganizationScopeSqliteGateway,
};
use agrr_domain::agricultural_task::constants::task_schedule_sync_states;
use agrr_domain::cultivation_plan::dtos::TaskScheduleTimeline;
use agrr_domain::cultivation_plan::dtos::RegenerateTaskScheduleInput;
use agrr_domain::cultivation_plan::interactors::{
    RegenerateTaskScheduleInteractor, TaskScheduleItemCreateInteractor,
    TaskScheduleItemSkipInteractor, TaskScheduleItemUpdateInteractor,
    TaskScheduleTimelineInteractor,
};
use agrr_domain::cultivation_plan::ports::{
    RegenerateTaskScheduleOutputPort, TaskScheduleItemMutationOutputPort,
    TaskScheduleRegenEnqueuePort, TaskScheduleTimelineOutputPort,
};
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{get, patch, post},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/{id}/task_schedule",
            get(show_task_schedule),
        )
        .route(
            "/api/v1/plans/{plan_id}/task_schedule/items",
            post(create_task_schedule_item),
        )
        .route(
            "/api/v1/plans/{plan_id}/task_schedule/items/{item_id}",
            patch(update_task_schedule_item),
        )
        .route(
            "/api/v1/plans/{plan_id}/task_schedule/items/{item_id}/skip",
            patch(skip_task_schedule_item),
        )
        .route(
            "/api/v1/plans/{plan_id}/task_schedule/items/{item_id}/unskip",
            patch(unskip_task_schedule_item),
        )
        .route(
            "/api/v1/plans/{id}/task_schedule/regenerate",
            post(regenerate_task_schedule),
        )
}

#[derive(Deserialize, Default)]
struct TimelineParams {
    week_start: Option<String>,
    field_cultivation_id: Option<i64>,
    category: Option<String>,
    scope: Option<String>,
}

struct TimelinePresenter {
    body: Option<TimelineOutcome>,
}

enum TimelineOutcome {
    Success(TaskScheduleTimeline),
    NotFound,
}

impl TaskScheduleTimelineOutputPort for TimelinePresenter {
    fn on_success(&mut self, dto: TaskScheduleTimeline) {
        self.body = Some(TimelineOutcome::Success(dto));
    }

    fn on_failure(&mut self, _error: Error) {
        self.body = Some(TimelineOutcome::NotFound);
    }
}

async fn show_task_schedule(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Query(params): Query<TimelineParams>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let private_read = CultivationPlanPrivateSnapshotReadSqliteGateway::new(pool.clone());
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let clock = SystemClock;
    let mut presenter = TimelinePresenter { body: None };

    let mut interactor = TaskScheduleTimelineInteractor::new(
        &mut presenter,
        user_id,
        plan_id,
        &private_read,
        &plan_gateway,
        &translator,
        &logger,
        &user_lookup,
        &clock,
        &scope_gateway,
    );
    if let Err(err) = interactor.call() {
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["plans.errors.not_found"]})),
            ));
        }
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
        ));
    }

    match presenter.body {
        Some(TimelineOutcome::Success(timeline)) => {
            let query = TaskScheduleQuery {
                week_start: params.week_start,
                field_cultivation_id: params.field_cultivation_id,
                category: params.category,
                scope: params.scope,
            };
            Ok(Json(to_json_body(timeline, query)))
        }
        Some(TimelineOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["plans.errors.not_found"]})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["no response"]})),
        )),
    }
}

struct MutationPresenter {
    body: Option<MutationOutcome>,
}

enum MutationOutcome {
    Success(Value),
    NotFound,
    RecordInvalid(BTreeMap<String, Vec<String>>),
}

impl TaskScheduleItemMutationOutputPort for MutationPresenter {
    fn on_created(&mut self, item_payload: Value) {
        self.body = Some(MutationOutcome::Success(item_payload));
    }

    fn on_success(&mut self, item_payload: Value) {
        self.body = Some(MutationOutcome::Success(item_payload));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.body = Some(MutationOutcome::RecordInvalid(errors));
    }

    fn on_not_found(&mut self) {
        self.body = Some(MutationOutcome::NotFound);
    }
}

#[derive(Deserialize)]
struct TaskScheduleItemBody {
    task_schedule_item: BTreeMap<String, Value>,
}

fn json_value_to_attr(v: &Value) -> AttrValue {
    match v {
        Value::Null => AttrValue::Null,
        Value::Bool(b) => AttrValue::Bool(*b),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                AttrValue::Int(i)
            } else {
                AttrValue::Str(n.to_string())
            }
        }
        Value::String(s) => AttrValue::Str(s.clone()),
        _ => AttrValue::Str(v.to_string()),
    }
}

fn attr_map_from_json_map(map: &BTreeMap<String, Value>) -> AttrMap {
    attr_map_from_pairs(
        map.iter()
            .map(|(k, v)| (k.clone(), json_value_to_attr(v))),
    )
}

async fn create_task_schedule_item(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<TaskScheduleItemBody>,
) -> Result<(StatusCode, Json<Value>), (axum::http::StatusCode, Json<Value>)> {
    run_item_mutation(
        &state,
        &jar,
        plan_id,
        None,
        attr_map_from_json_map(&body.task_schedule_item),
        true,
    )
    .await
}

async fn update_task_schedule_item(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, item_id)): Path<(i64, i64)>,
    Json(body): Json<TaskScheduleItemBody>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let (_, json) = run_item_mutation(
        &state,
        &jar,
        plan_id,
        Some(item_id),
        attr_map_from_json_map(&body.task_schedule_item),
        false,
    )
    .await?;
    Ok(json)
}

async fn run_item_mutation(
    state: &AppState,
    jar: &CookieJar,
    plan_id: i64,
    item_id: Option<i64>,
    attributes: AttrMap,
    creating: bool,
) -> Result<(StatusCode, Json<Value>), (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(state, jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool.clone());
    let mutation_gateway = TaskScheduleItemMutationSqliteGateway::new(pool);
    let clock = SystemClock;
    let mut presenter = MutationPresenter { body: None };

    let result = if creating {
        let mut interactor = TaskScheduleItemCreateInteractor::new(
            &mut presenter,
            &plan_gateway,
            &mutation_gateway,
            &scope_gateway,
        );
        interactor.call_rescuing(user_id, plan_id, attributes)
    } else {
        let item_id = item_id.expect("item_id required for update");
        let mut interactor = TaskScheduleItemUpdateInteractor::new(
            &mut presenter,
            &plan_gateway,
            &mutation_gateway,
            &clock,
            &scope_gateway,
        );
        interactor.call_rescuing(user_id, plan_id, item_id, attributes)
    };

    if let Err(err) = result {
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["plans.errors.not_found"]})),
            ));
        }
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
        ));
    }

    let success_status = if creating {
        StatusCode::CREATED
    } else {
        StatusCode::OK
    };

    match presenter.body {
        Some(MutationOutcome::Success(item)) => Ok((success_status, Json(json!({ "item": item })))),
        Some(MutationOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["plans.errors.not_found"]})),
        )),
        Some(MutationOutcome::RecordInvalid(errors)) => Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({ "errors": errors })),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["no response"]})),
        )),
    }
}

async fn skip_task_schedule_item(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, item_id)): Path<(i64, i64)>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    run_skip_mutation(&state, &jar, plan_id, item_id, true).await
}

async fn unskip_task_schedule_item(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, item_id)): Path<(i64, i64)>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    run_skip_mutation(&state, &jar, plan_id, item_id, false).await
}

async fn run_skip_mutation(
    state: &AppState,
    jar: &CookieJar,
    plan_id: i64,
    item_id: i64,
    skipping: bool,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(state, jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool.clone());
    let mutation_gateway = TaskScheduleItemMutationSqliteGateway::new(pool);
    let clock = SystemClock;
    let mut presenter = MutationPresenter { body: None };

    let mut interactor = TaskScheduleItemSkipInteractor::new(
        &mut presenter,
        &plan_gateway,
        &mutation_gateway,
        &clock,
        &scope_gateway,
    );

    let result = if skipping {
        interactor.call_skip_rescuing(user_id, plan_id, item_id)
    } else {
        interactor.call_unskip_rescuing(user_id, plan_id, item_id)
    };

    if let Err(err) = result {
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["plans.errors.not_found"]})),
            ));
        }
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
        ));
    }

    match presenter.body {
        Some(MutationOutcome::Success(item)) => Ok(Json(json!({ "item": item }))),
        Some(MutationOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["plans.errors.not_found"]})),
        )),
        Some(MutationOutcome::RecordInvalid(errors)) => Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({ "errors": errors })),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["no response"]})),
        )),
    }
}

async fn regenerate_task_schedule(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);
    let enqueue = TaskScheduleRegenEnqueueAdapter {
        state: state.clone(),
    };
    let mut presenter = RegeneratePresenter { body: None };

    let mut interactor = RegenerateTaskScheduleInteractor::new(
        &mut presenter,
        &plan_gateway,
        &enqueue,
        &scope_gateway,
    );

    if let Err(_) = interactor.call(RegenerateTaskScheduleInput { user_id, plan_id }) {
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
        ));
    }

    match presenter.body {
        Some(RegenerateOutcome::Success(body)) => Ok(Json(body)),
        Some(RegenerateOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["plans.errors.not_found"]})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["no response"]})),
        )),
    }
}

struct TaskScheduleRegenEnqueueAdapter {
    state: AppState,
}

impl TaskScheduleRegenEnqueuePort for TaskScheduleRegenEnqueueAdapter {
    fn enqueue_immediate(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        crate::task_schedule_generation::enqueue_task_schedule_regen_immediate(&self.state, plan_id);
        Ok(())
    }
}

struct RegeneratePresenter {
    body: Option<RegenerateOutcome>,
}

enum RegenerateOutcome {
    Success(Value),
    NotFound,
}

impl RegenerateTaskScheduleOutputPort for RegeneratePresenter {
    fn on_success(&mut self) {
        self.body = Some(RegenerateOutcome::Success(json!({
            "success": true,
            "task_schedule_sync_state": task_schedule_sync_states::GENERATING,
        })));
    }

    fn on_not_found(&mut self) {
        self.body = Some(RegenerateOutcome::NotFound);
    }
}
