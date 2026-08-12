//! `GET /api/v1/plans/:id/plan_vs_actual/summary` — plan vs actual aggregation read model.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::plan_vs_actual_json::summary_to_json_body;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::PlanVsActualSummaryRead;
use agrr_domain::cultivation_plan::interactors::PlanVsActualSummaryInteractor;
use agrr_domain::cultivation_plan::ports::PlanVsActualSummaryOutputPort;
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
        "/api/v1/plans/{id}/plan_vs_actual/summary",
        get(show_plan_vs_actual_summary),
    )
}

#[derive(Deserialize, Default)]
struct SummaryParams {
    top_n: Option<usize>,
}

struct SummaryPresenter {
    body: Option<SummaryOutcome>,
}

enum SummaryOutcome {
    Success(PlanVsActualSummaryRead),
    NotFound,
}

impl PlanVsActualSummaryOutputPort for SummaryPresenter {
    fn on_success(&mut self, dto: PlanVsActualSummaryRead) {
        self.body = Some(SummaryOutcome::Success(dto));
    }

    fn on_failure(&mut self, _error: Error) {
        self.body = Some(SummaryOutcome::NotFound);
    }
}

async fn show_plan_vs_actual_summary(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Query(params): Query<SummaryParams>,
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

    let mut presenter = SummaryPresenter { body: None };
    let translator = PassthroughTranslator;
    let logger = NoopLogger;

    let top_n = params.top_n.unwrap_or(0);
    let mut interactor = PlanVsActualSummaryInteractor::new(
        &mut presenter,
        user_id,
        plan_id,
        top_n,
        &private_read,
        &plan_gateway,
        &translator,
        &logger,
        &user_lookup,
        &scope_gateway,
    );

    match interactor.call() {
        Ok(()) => match presenter.body {
            Some(SummaryOutcome::Success(summary)) => Ok(Json(summary_to_json_body(summary))),
            Some(SummaryOutcome::NotFound) | None => Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["not_found"]})),
            )),
        },
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["not_found"]})),
        )),
        Err(err) => {
            tracing::error!("plan_vs_actual summary failed: {err}");
            Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ))
        }
    }
}
