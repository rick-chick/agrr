//! `GET /api/v1/plans/:id/task_schedule` — private plan task timeline (P6).

use crate::adapters::{NoopLogger, PassthroughTranslator, SystemClock};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use crate::task_schedule_timeline_json::{to_json_body, TaskScheduleQuery};
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    UserLookupSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::TaskScheduleTimeline;
use agrr_domain::cultivation_plan::interactors::TaskScheduleTimelineInteractor;
use agrr_domain::cultivation_plan::ports::TaskScheduleTimelineOutputPort;
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, Query, State},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/{id}/task_schedule",
        get(show_task_schedule),
    )
}

#[derive(Deserialize, Default)]
struct TimelineParams {
    week_start: Option<String>,
    field_cultivation_id: Option<i64>,
    category: Option<String>,
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
