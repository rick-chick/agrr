//! `GET /api/v1/plans/:id/weather_reschedule_proposals` and preview dry-run.

use crate::adjust_weather_prediction::SqliteAdjustWeatherPredictionGateway;
use crate::adapters::{
    NoopOptimizationEventsGateway, PassthroughTranslator, StderrLogger, SystemClock,
};
use crate::plan_allocation_adjust_debug_dump::plan_allocation_adjust_debug_dump;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_agrr::PlanAllocationAdjustAgrrDaemonGateway;
use agrr_adapters_sqlite::{
    CultivationPlanSqliteGateway, FieldCultivationSyncPlanReadSqliteGateway,
    FieldCultivationSyncSqliteGateway, PlanAllocationAdjustReadSqliteGateway,
    UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
    WeatherRescheduleProposalReadSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::{
    PlanAllocationAdjustFailure, WeatherRescheduleProposalPreviewRead, WeatherRescheduleProposalRead,
};
use agrr_domain::cultivation_plan::interactors::{
    WeatherRescheduleProposalPreviewInteractor, WeatherRescheduleProposalsListInteractor,
};
use agrr_domain::cultivation_plan::ports::{
    WeatherRescheduleProposalPreviewOutputPort, WeatherRescheduleProposalsListOutputPort,
};
use agrr_domain::field_cultivation::interactors::FieldCultivationSyncInteractor;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/{id}/weather_reschedule_proposals",
            get(list_weather_reschedule_proposals),
        )
        .route(
            "/api/v1/plans/{id}/weather_reschedule_proposals/{proposal_id}/preview",
            post(preview_weather_reschedule_proposal),
        )
}

struct ListPresenter {
    body: Option<Vec<WeatherRescheduleProposalRead>>,
}

impl WeatherRescheduleProposalsListOutputPort for ListPresenter {
    fn on_success(&mut self, proposals: Vec<WeatherRescheduleProposalRead>) {
        self.body = Some(proposals);
    }
}

struct PreviewPresenter {
    body: Option<PreviewOutcome>,
}

enum PreviewOutcome {
    Success(WeatherRescheduleProposalPreviewRead),
    Failure(StatusCodePayload),
}

struct StatusCodePayload {
    status: axum::http::StatusCode,
    body: Value,
}

impl WeatherRescheduleProposalPreviewOutputPort for PreviewPresenter {
    fn on_success(&mut self, preview: WeatherRescheduleProposalPreviewRead) {
        self.body = Some(PreviewOutcome::Success(preview));
    }

    fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        let status = preview_failure_status(&failure.kind);
        self.body = Some(PreviewOutcome::Failure(StatusCodePayload {
            status,
            body: json!({ "errors": [failure.message] }),
        }));
    }
}

fn preview_failure_status(kind: &str) -> axum::http::StatusCode {
    match kind {
        PlanAllocationAdjustFailure::KIND_NO_WEATHER_LOCATION
        | PlanAllocationAdjustFailure::KIND_NOT_FOUND => axum::http::StatusCode::NOT_FOUND,
        PlanAllocationAdjustFailure::KIND_INVALID_DATE
        | PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES => {
            axum::http::StatusCode::BAD_REQUEST
        }
        _ => axum::http::StatusCode::INTERNAL_SERVER_ERROR,
    }
}

fn proposals_to_json(proposals: Vec<WeatherRescheduleProposalRead>) -> Value {
    serde_json::to_value(proposals).unwrap_or_else(|_| json!([]))
}

fn preview_to_json(preview: WeatherRescheduleProposalPreviewRead) -> Value {
    serde_json::to_value(preview).unwrap_or_else(|_| json!({}))
}

async fn list_weather_reschedule_proposals(
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
    let read_gateway = WeatherRescheduleProposalReadSqliteGateway::new(
        pool.clone(),
        state.predicted_weather.store.clone(),
    );
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

    let mut presenter = ListPresenter { body: None };

    let mut interactor = WeatherRescheduleProposalsListInteractor::new(
        &mut presenter,
        user_id,
        plan_id,
        &plan_gateway,
        &read_gateway,
        &user_lookup,
        &scope_gateway,
    );

    match interactor.call() {
        Ok(()) => {
            let proposals = presenter.body.unwrap_or_default();
            Ok(Json(proposals_to_json(proposals)))
        }
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["not_found"]})),
        )),
        Err(err) => {
            tracing::error!("weather_reschedule_proposals list failed: {err}");
            Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ))
        }
    }
}

async fn preview_weather_reschedule_proposal(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((plan_id, proposal_id)): Path<(i64, String)>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let read_gateway = WeatherRescheduleProposalReadSqliteGateway::new(
        pool.clone(),
        state.predicted_weather.store.clone(),
    );
    let adjust_read_gateway = PlanAllocationAdjustReadSqliteGateway::new(
        pool.clone(),
        state.weather_data.clone(),
        state.predicted_weather.metadata.clone(),
    );
    let adjust_gateway = PlanAllocationAdjustAgrrDaemonGateway::from_env();
    let weather_prediction_gateway = SqliteAdjustWeatherPredictionGateway::from_state(&state);
    let events = NoopOptimizationEventsGateway;
    let logger = StderrLogger;
    let translator = PassthroughTranslator;
    let clock = SystemClock;
    let debug_dump = plan_allocation_adjust_debug_dump(&clock, &logger);
    let rule_seed = format!(
        "{:08x}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos() as u32
    );
    let sync_gateway = FieldCultivationSyncSqliteGateway::new(pool.clone());
    let sync_read = FieldCultivationSyncPlanReadSqliteGateway::new(pool.clone());
    let mut field_cultivation_sync =
        FieldCultivationSyncInteractor::new(&sync_gateway, &sync_read, &logger);
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

    let mut presenter = PreviewPresenter { body: None };
    let mut interactor = WeatherRescheduleProposalPreviewInteractor::new(
        &mut presenter,
        &logger,
        &translator,
        &clock,
        user_id,
        plan_id,
        proposal_id,
        &plan_gateway,
        &read_gateway,
        &adjust_read_gateway,
        &adjust_gateway,
        &events,
        &debug_dump,
        &weather_prediction_gateway,
        &mut field_cultivation_sync,
        &rule_seed,
        &user_lookup,
        &scope_gateway,
    );

    match interactor.call() {
        Ok(()) => match presenter.body {
            Some(PreviewOutcome::Success(preview)) => Ok(Json(preview_to_json(preview))),
            Some(PreviewOutcome::Failure(payload)) => Err((payload.status, Json(payload.body))),
            None => Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )),
        },
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["not_found"]})),
        )),
        Err(err) => {
            tracing::error!("weather_reschedule_proposals preview failed: {err}");
            Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ))
        }
    }
}
