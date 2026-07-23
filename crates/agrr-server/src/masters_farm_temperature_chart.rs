//! `GET /api/v1/masters/farms/{id}/temperature_chart`

use crate::adapters::SystemClock;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    FarmSqliteGateway, FarmTemperatureChartWeatherFromStorageGateway, UserLookupSqliteGateway,
    WeatherDataGatewayBundle,
};
use agrr_domain::farm::dtos::{
    FarmTemperatureChartInput, FarmTemperatureChartOutput, FarmTemperatureChartPoint,
};
use agrr_domain::farm::interactors::FarmTemperatureChartInteractor;
use agrr_domain::farm::ports::{
    FarmTemperatureChartOutputPort, TemperatureChartFailure,
};
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/masters/farms/{id}/temperature_chart",
        get(show_farm_temperature_chart),
    )
}

#[derive(Deserialize)]
struct TemperatureChartQuery {
    period: Option<String>,
}

async fn show_farm_temperature_chart(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(farm_id): Path<i64>,
    Query(query): Query<TemperatureChartQuery>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let pool = state.sqlite.clone();
    let farm_gateway = FarmSqliteGateway::new(pool.clone());
    let weather_bundle = WeatherDataGatewayBundle::resolve(pool.clone())
        .map_err(|_| internal_error())?;
    let weather_gateway = FarmTemperatureChartWeatherFromStorageGateway::new(&weather_bundle);
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let clock = SystemClock;

    let mut presenter = TemperatureChartPresenter { body: None };
    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut presenter,
        user_id,
        &farm_gateway,
        &weather_gateway,
        &clock,
        &user_lookup,
    );

    interactor
        .call(FarmTemperatureChartInput::new(farm_id, query.period))
        .map_err(internal)?;

    match presenter.body {
        Some(Ok(output)) => Ok(Json(temperature_chart_to_json(&output))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

struct TemperatureChartPresenter {
    body: Option<Result<FarmTemperatureChartOutput, (StatusCode, Value)>>,
}

impl FarmTemperatureChartOutputPort for TemperatureChartPresenter {
    fn on_success(&mut self, output: FarmTemperatureChartOutput) {
        self.body = Some(Ok(output));
    }

    fn on_failure(&mut self, error: TemperatureChartFailure) {
        self.body = Some(Err(temperature_chart_failure(error)));
    }
}

fn temperature_chart_to_json(output: &FarmTemperatureChartOutput) -> Value {
    json!({
        "farm_id": output.farm_id,
        "period": output.period,
        "start_date": output.start_date.to_string(),
        "end_date": output.end_date.to_string(),
        "observed_only": output.observed_only,
        "data_quality": {
            "expected_days": output.data_quality.expected_days,
            "present_days": output.data_quality.present_days,
            "missing_days": output.data_quality.missing_days,
        },
        "points": output.points.iter().map(point_to_json).collect::<Vec<_>>(),
    })
}

fn point_to_json(point: &FarmTemperatureChartPoint) -> Value {
    let mut obj = serde_json::Map::new();
    obj.insert("date".into(), json!(point.date.to_string()));
    if let Some(v) = point.temperature_min {
        obj.insert("temperature_min".into(), json!(v));
    }
    if let Some(v) = point.temperature_mean {
        obj.insert("temperature_mean".into(), json!(v));
    }
    if let Some(v) = point.temperature_max {
        obj.insert("temperature_max".into(), json!(v));
    }
    Value::Object(obj)
}

fn temperature_chart_failure(error: TemperatureChartFailure) -> (StatusCode, Value) {
    match error {
        TemperatureChartFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::NOT_FOUND,
            json!({"error": "not_found"}),
        ),
        TemperatureChartFailure::NotFound(e) => (
            StatusCode::NOT_FOUND,
            json!({"error": e.message}),
        ),
        TemperatureChartFailure::WeatherNotReady { status, progress } => (
            StatusCode::CONFLICT,
            json!({
                "error": "weather_data_not_ready",
                "weather_data_status": status,
                "weather_data_progress": progress,
            }),
        ),
        TemperatureChartFailure::MissingWeatherLocation(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
        TemperatureChartFailure::Storage(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            json!({"error": e.message}),
        ),
    }
}

fn internal(error: Box<dyn std::error::Error + Send + Sync>) -> (StatusCode, Json<Value>) {
    let _ = error;
    internal_error()
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )
}
