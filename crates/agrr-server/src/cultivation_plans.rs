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

#[derive(Debug)]
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
            Json(json!({"success": false, "errors": ["unauthorized"]})),
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
                Json(json!({"success": false, "errors": [e.to_string()]})),
            )
        })?;

    match presenter.body {
        Some(DataOutcome::Success(body)) => Ok(Json(body)),
        Some(DataOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"success": false, "errors": ["not found"]})),
        )),
        Some(DataOutcome::Unexpected(msg)) => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "errors": [msg]})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "errors": ["no response"]})),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::cultivation_plan::dtos::cultivation_plan_workbench::{
        CultivationPlanWorkbenchPlanHeader, CultivationPlanWorkbenchSnapshot,
    };

    #[test]
    fn data_presenter_maps_not_found() {
        let mut presenter = DataPresenter { body: None };
        presenter.on_not_found();
        assert!(matches!(presenter.body, Some(DataOutcome::NotFound)));
    }

    #[test]
    fn data_presenter_maps_unexpected_message() {
        let mut presenter = DataPresenter { body: None };
        presenter.on_unexpected("load failed");
        match presenter.body {
            Some(DataOutcome::Unexpected(msg)) => assert_eq!(msg, "load failed"),
            other => panic!("expected unexpected, got {other:?}"),
        }
    }

    #[test]
    fn data_presenter_success_uses_workbench_payload_shape() {
        let mut presenter = DataPresenter { body: None };
        presenter.on_success(CultivationPlanWorkbenchSnapshot {
            plan: CultivationPlanWorkbenchPlanHeader {
                id: 9,
                user_id: Some(1),
                plan_year: Some(2026),
                plan_name: Some("Plan".into()),
                plan_type: "private".into(),
                status: "completed".into(),
                total_area: 100.0,
                planning_start_date: Some("2026-01-01".into()),
                planning_end_date: Some("2026-12-31".into()),
                total_profit: 1.0,
                total_revenue: 2.0,
                total_cost: 1.0,
            },
            fields: vec![json!({"id": 1})],
            crops: vec![],
            cultivations: vec![],
            available_crop_rows: vec![],
            farm_region: "jp".into(),
        });

        match presenter.body {
            Some(DataOutcome::Success(body)) => {
                assert_eq!(body["success"], true);
                assert_eq!(body["data"]["id"], 9);
                assert_eq!(body["data"]["plan_name"], "Plan");
                assert_eq!(body["total_profit"], 1.0);
            }
            other => panic!("expected success body, got {other:?}"),
        }
    }
}