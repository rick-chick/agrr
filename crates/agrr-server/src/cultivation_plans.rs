//! `GET /api/v1/plans/cultivation_plans/:id/data` — workbench payload (P6).

use crate::adapters::NoopLogger;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use crate::workbench_payload;
use agrr_adapters_sqlite::{
    CropRowsAvailablePrivateSqliteGateway, CultivationPlanRestPlanReadDomainSqliteGateway,
    CultivationPlanRestPlanReadSqliteGateway, CultivationPlanSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use agrr_domain::cultivation_plan::dtos::cultivation_plan_workbench::CultivationPlanWorkbenchSnapshot;
use agrr_domain::cultivation_plan::interactors::RetrieveCultivationPlanInteractor;
use agrr_domain::cultivation_plan::ports::RetrieveCultivationPlanOutputPort;
use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/cultivation_plans/{id}/data",
        get(private_plan_data),
    )
}

struct DataPresenter {
    body: Option<DataOutcome>,
}

enum DataOutcome {
    Success(Value),
    NotFound,
    Unexpected(String),
}

impl RetrieveCultivationPlanOutputPort for DataPresenter {
    fn on_success(&mut self, snapshot: CultivationPlanWorkbenchSnapshot) {
        self.body = Some(DataOutcome::Success(workbench_payload::to_json_body(snapshot)));
    }

    fn on_not_found(&mut self) {
        self.body = Some(DataOutcome::NotFound);
    }

    fn on_unexpected(&mut self, message: &str) {
        self.body = Some(DataOutcome::Unexpected(message.to_string()));
    }
}

async fn private_plan_data(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"success": false, "message": "unauthorized"})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let rest_read = CultivationPlanRestPlanReadDomainSqliteGateway::new(
        CultivationPlanRestPlanReadSqliteGateway::new(pool.clone()),
    );
    let crop_rows = CropRowsAvailablePrivateSqliteGateway::new(pool);
    let logger = NoopLogger;
    let mut presenter = DataPresenter { body: None };

    let auth = CultivationPlanRestAuth::private(user_id);
    let mut interactor = RetrieveCultivationPlanInteractor::new(
        &mut presenter,
        &plan_gateway,
        &rest_read,
        &crop_rows,
        &logger,
    );

    interactor
        .call_catch_all(&auth, plan_id)
        .map_err(|e| {
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"success": false, "message": e.to_string()})),
            )
        })?;

    match presenter.body {
        Some(DataOutcome::Success(body)) => Ok(Json(body)),
        Some(DataOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"success": false, "message": "not found"})),
        )),
        Some(DataOutcome::Unexpected(msg)) => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}
