//! `GET /api/v1/masters/farms/{farm_id}/temperature_chart`

use crate::adapters::SystemClock;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{FarmSqliteGateway, UserLookupSqliteGateway};
use agrr_adapters_sqlite::WeatherDataGatewayBundle;
use agrr_domain::farm::dtos::FarmTemperatureChartInput;
use agrr_domain::farm::dtos::FarmTemperatureChartOutput;
use agrr_domain::farm::interactors::FarmTemperatureChartInteractor;
use agrr_domain::farm::ports::{
    FarmTemperatureChartFailure, FarmTemperatureChartOutputPort,
};
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use time::Date;

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/masters/farms/{farm_id}/temperature_chart",
        get(temperature_chart),
    )
}

#[derive(Deserialize)]
struct TemperatureChartQuery {
    period: Option<String>,
}

struct ChartPresenter {
    body: Option<ChartOutcome>,
}

enum ChartOutcome {
    Success(FarmTemperatureChartOutput),
    Failure(FarmTemperatureChartFailure),
}

impl FarmTemperatureChartOutputPort for ChartPresenter {
    fn on_success(&mut self, output: FarmTemperatureChartOutput) {
        self.body = Some(ChartOutcome::Success(output));
    }

    fn on_failure(&mut self, failure: FarmTemperatureChartFailure) {
        self.body = Some(ChartOutcome::Failure(failure));
    }
}

async fn temperature_chart(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(farm_id): Path<i64>,
    Query(query): Query<TemperatureChartQuery>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let pool = state.sqlite.clone();
    let farm_gateway = FarmSqliteGateway::new(pool.clone());
    let weather_bundle = WeatherDataGatewayBundle::resolve(pool.clone()).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )
    })?;
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let clock = SystemClock;
    let mut presenter = ChartPresenter { body: None };
    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut presenter,
        &farm_gateway,
        &weather_bundle,
        &user_lookup,
        &clock,
    );
    let input = FarmTemperatureChartInput {
        farm_id,
        user_id,
        period: query.period.unwrap_or_else(|| "90d".into()),
    };
    interactor.call(input).map_err(|_| internal_error())?;

    match presenter.body {
        Some(ChartOutcome::Success(output)) => Ok(Json(success_json(&output))),
        Some(ChartOutcome::Failure(failure)) => Err(chart_failure(failure)),
        None => Err(internal_error()),
    }
}

fn success_json(output: &FarmTemperatureChartOutput) -> Value {
    json!({
        "farm_id": output.farm_id,
        "period": output.period,
        "start_date": format_date(output.start_date),
        "end_date": format_date(output.end_date),
        "observed_only": output.observed_only,
        "data_quality": {
            "expected_days": output.data_quality.expected_days,
            "present_days": output.data_quality.present_days,
            "missing_days": output.data_quality.missing_days,
        },
        "points": output.points.iter().map(|point| {
            let mut obj = serde_json::Map::new();
            obj.insert("date".into(), json!(format_date(point.date)));
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
        }).collect::<Vec<_>>(),
    })
}

fn format_date(date: Date) -> String {
    format!("{:04}-{:02}-{:02}", date.year(), u8::from(date.month()), date.day())
}

fn chart_failure(failure: FarmTemperatureChartFailure) -> (StatusCode, Json<Value>) {
    match failure {
        FarmTemperatureChartFailure::NotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "farm not found"})),
        ),
        FarmTemperatureChartFailure::WeatherNotReady { status, progress } => (
            StatusCode::CONFLICT,
            Json(json!({
                "error": "weather_data_not_ready",
                "weather_data_status": status,
                "weather_data_progress": progress,
            })),
        ),
        FarmTemperatureChartFailure::NoWeatherLocation => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "farms.weather_data.no_weather_data"})),
        ),
        FarmTemperatureChartFailure::StorageUnavailable => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "weather data storage unavailable"})),
        ),
    }
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )
}
