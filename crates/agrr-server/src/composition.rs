//! Per-request gateway / interactor wiring (Ruby `CompositionRoot` equivalent).

use std::sync::Arc;

use agrr_adapters_sqlite::FieldCultivationClimateSourceSqliteGateway;
use agrr_domain::field_cultivation::gateways::FieldCultivationGateway;
use axum::{extract::State, routing::get, Json, Router};
use serde::Serialize;

#[derive(Clone)]
pub struct AppState {
    pub sqlite_path: Arc<String>,
}

pub fn api_routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/field_cultivations/:id/summary",
        get(field_cultivation_summary),
    )
}

#[derive(Serialize)]
struct SummaryResponse {
    id: i64,
    field_name: String,
    crop_name: String,
}

async fn field_cultivation_summary(
    State(state): State<AppState>,
    axum::extract::Path(id): axum::extract::Path<i64>,
) -> Result<Json<SummaryResponse>, axum::http::StatusCode> {
    let gateway =
        FieldCultivationClimateSourceSqliteGateway::new(state.sqlite_path.as_str());
    let summary = FieldCultivationGateway::find_api_summary_by_field_cultivation_id(&gateway, id)
        .map_err(|_| axum::http::StatusCode::NOT_FOUND)?;
    Ok(Json(SummaryResponse {
        id: summary.id,
        field_name: summary.field_name,
        crop_name: summary.crop_name,
    }))
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            sqlite_path: Arc::new(
                std::env::var("AGRR_SQLITE_PATH").unwrap_or_else(|_| "storage/development.sqlite3".into()),
            ),
        }
    }
}
