//! `GET /api/v1/plans/:id/weather_reschedule_proposals` — proactive weather-triggered adjust proposals.

use crate::adapters::NoopLogger;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanSqliteGateway, UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
    WeatherRescheduleProposalsSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::WeatherRescheduleProposalRead;
use agrr_domain::cultivation_plan::interactors::WeatherRescheduleProposalsListInteractor;
use agrr_domain::cultivation_plan::ports::WeatherRescheduleProposalsListOutputPort;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/{id}/weather_reschedule_proposals",
        get(list_weather_reschedule_proposals),
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

fn proposals_to_json(proposals: Vec<WeatherRescheduleProposalRead>) -> Value {
    serde_json::to_value(proposals).unwrap_or_else(|_| json!([]))
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
    let proposals_gateway = WeatherRescheduleProposalsSqliteGateway::new();
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

    let mut presenter = ListPresenter { body: None };

    let mut interactor = WeatherRescheduleProposalsListInteractor::new(
        &mut presenter,
        user_id,
        plan_id,
        &plan_gateway,
        &proposals_gateway,
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
