//! `GET /api/v1/work/variance_portfolio` — farm × plan variance summary aggregation.

use crate::adapters::NoopLogger;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanPrivateReadSqliteGateway, CultivationPlanPrivateSnapshotReadSqliteGateway,
    CultivationPlanSqliteGateway, PlanVarianceLearningSqliteGateway, UserLookupSqliteGateway,
    UserOrganizationScopeSqliteGateway,
};
use agrr_domain::shared::dtos::Error;
use agrr_domain::work_record::dtos::VariancePortfolioRow;
use agrr_domain::work_record::interactors::VariancePortfolioInteractor;
use agrr_domain::work_record::ports::VariancePortfolioOutputPort;
use axum::{
    extract::State,
    http::StatusCode,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Serialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/work/variance_portfolio",
        get(list_variance_portfolio),
    )
}

#[derive(Serialize)]
struct VariancePortfolioItem {
    farm_id: i64,
    farm_name: String,
    plan_id: i64,
    plan_year: Option<i32>,
    status: String,
    unrecorded_count: i64,
    gdd_delay_count: i64,
    threshold_exceeded_count: i64,
    days_threshold_exceeded_count: i64,
    carryover_not_imported: bool,
}

struct ListPresenter {
    body: Option<Result<Vec<VariancePortfolioItem>, (String, u16)>>,
}

impl VariancePortfolioOutputPort for ListPresenter {
    fn on_success(&mut self, rows: Vec<VariancePortfolioRow>) {
        let payload = rows
            .into_iter()
            .map(|row| VariancePortfolioItem {
                farm_id: row.farm_id,
                farm_name: row.farm_name,
                plan_id: row.plan_id,
                plan_year: row.plan_year,
                status: row.status,
                unrecorded_count: row.unrecorded_count,
                gdd_delay_count: row.gdd_delay_count,
                threshold_exceeded_count: row.threshold_exceeded_count,
                days_threshold_exceeded_count: row.days_threshold_exceeded_count,
                carryover_not_imported: row.carryover_not_imported,
            })
            .collect();
        self.body = Some(Ok(payload));
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(Err((error.message, 422)));
    }
}

async fn list_variance_portfolio(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({ "error": "unauthorized" })),
        )
    })?;

    let pool = state.sqlite.clone();
    let private_read = CultivationPlanPrivateReadSqliteGateway::new(pool.clone());
    let private_snapshot = CultivationPlanPrivateSnapshotReadSqliteGateway::new(pool.clone());
    let variance_learning = PlanVarianceLearningSqliteGateway::new(pool.clone());
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);

    let logger = NoopLogger;
    let mut presenter = ListPresenter { body: None };
    let mut interactor = VariancePortfolioInteractor::new(
        &mut presenter,
        user_id,
        &private_read,
        &private_snapshot,
        &variance_learning,
        &plan_gateway,
        &crate::adapters::PassthroughTranslator,
        &logger,
        &user_lookup,
        &scope_gateway,
    );

    interactor
        .call()
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(Ok(rows)) => Ok(Json(json!(rows))),
        Some(Err((message, status))) => Err((
            StatusCode::from_u16(status).unwrap_or(StatusCode::UNPROCESSABLE_ENTITY),
            Json(json!({ "error": message })),
        )),
        None => Err(internal_error()),
    }
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({ "error": "Internal server error" })),
    )
}
