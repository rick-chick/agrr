//! `GET /api/v1/work/hub` — work hub farm rows with plan resolution.

use crate::adapters::NoopLogger;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::WorkHubReadSqliteGateway;
use agrr_domain::shared::dtos::Error;
use agrr_domain::work_record::dtos::WorkHubFarmRow;
use agrr_domain::work_record::interactors::WorkHubListInteractor;
use agrr_domain::work_record::ports::WorkHubListOutputPort;
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
    Router::new().route("/api/v1/work/hub", get(list_work_hub))
}

#[derive(Serialize)]
struct WorkHubFarmItem {
    farm_id: i64,
    farm_name: String,
    field_count: i32,
    total_area: f64,
    has_valid_fields: bool,
    plan_id: Option<i64>,
}

struct ListPresenter {
    body: Option<Result<Vec<WorkHubFarmItem>, (String, u16)>>,
}

impl WorkHubListOutputPort for ListPresenter {
    fn on_success(&mut self, rows: Vec<WorkHubFarmRow>) {
        let payload = rows
            .into_iter()
            .map(|row| WorkHubFarmItem {
                farm_id: row.farm_id,
                farm_name: row.farm_name,
                field_count: row.field_count,
                total_area: row.total_area,
                has_valid_fields: row.has_valid_fields,
                plan_id: row.plan_id,
            })
            .collect();
        self.body = Some(Ok(payload));
    }

    fn on_failure(&mut self, error: Error) {
        self.body = Some(Err((error.message, 422)));
    }
}

async fn list_work_hub(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({ "errors": ["unauthorized"] })),
        )
    })?;

    let pool = state.sqlite.clone();
    let gateway = WorkHubReadSqliteGateway::new(pool);
    let logger = NoopLogger;
    let mut presenter = ListPresenter { body: None };
    let mut interactor = WorkHubListInteractor::new(&mut presenter, user_id, &gateway, &logger);
    interactor
        .call()
        .map_err(|_| internal_error())?;

    match presenter.body {
        Some(Ok(rows)) => Ok(Json(json!(rows))),
        Some(Err((message, status))) => Err((
            StatusCode::from_u16(status).unwrap_or(StatusCode::UNPROCESSABLE_ENTITY),
            Json(json!({ "errors": [message]})),
        )),
        None => Err(internal_error()),
    }
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({ "errors": ["Internal server error"] })),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::shared::dtos::Error;
    use agrr_domain::work_record::dtos::WorkHubFarmRow;
    use agrr_domain::work_record::ports::WorkHubListOutputPort;

    #[test]
    fn list_presenter_maps_success_rows_to_items() {
        let mut presenter = ListPresenter { body: None };
        presenter.on_success(vec![WorkHubFarmRow {
            farm_id: 7,
            farm_name: "North".into(),
            field_count: 2,
            total_area: 1.5,
            has_valid_fields: true,
            plan_id: Some(99),
        }]);

        let rows = match presenter.body {
            Some(Ok(rows)) => rows,
            _ => panic!("expected success rows"),
        };
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].farm_id, 7);
        assert_eq!(rows[0].farm_name, "North");
        assert_eq!(rows[0].plan_id, Some(99));
    }

    #[test]
    fn list_presenter_on_failure_uses_422_status_code() {
        let mut presenter = ListPresenter { body: None };
        presenter.on_failure(Error::new("hub unavailable"));

        match presenter.body {
            Some(Err((message, status))) => {
                assert_eq!(message, "hub unavailable");
                assert_eq!(status, 422);
            }
            _ => panic!("expected failure"),
        }
    }
}