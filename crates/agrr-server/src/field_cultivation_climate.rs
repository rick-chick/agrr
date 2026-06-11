//! `GET .../field_cultivations/:id/climate_data` — domain interactor wiring.

use crate::adapters::{NoopLogger, PassthroughTranslator, SystemClock};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_adapters_sqlite::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    FieldCultivationPlanPredictedWeatherSqliteGateway,
    FieldCultivationWeatherDataFromStorageGateway, UserLookupSqliteGateway,
    WeatherDataGatewayBundle,
};
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use agrr_domain::field_cultivation::dtos::{
    FieldCultivationClimateDataInput, FieldCultivationClimateDataOutput,
};
use agrr_domain::field_cultivation::interactors::FieldCultivationClimateDataInteractor;
use agrr_domain::field_cultivation::ports::{
    FieldCultivationClimateDataInputPort, FieldCultivationClimateDataOutputPort,
};
use agrr_domain::field_cultivation::gateways::FieldCultivationWeatherPredictionServiceGateway;
use agrr_domain::field_cultivation::dtos::CultivationPlanWeatherInput;
use agrr_domain::shared::dtos::Error;
use agrr_domain::field_cultivation::ports::{
    WeatherPredictionAnchors, WeatherPredictionAnchorsPort,
};
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};
use time::Date;

struct ClimatePresenter {
    body: Option<ClimateOutcome>,
}

enum ClimateOutcome {
    Success(FieldCultivationClimateDataOutput),
    Error(String),
}

impl FieldCultivationClimateDataOutputPort for ClimatePresenter {
    fn present(&mut self, data: FieldCultivationClimateDataOutput) {
        self.body = Some(ClimateOutcome::Success(data));
    }

    fn on_error(&mut self, error: Error) {
        self.body = Some(ClimateOutcome::Error(error.message));
    }
}

struct FixedAnchors;

impl WeatherPredictionAnchorsPort for FixedAnchors {
    fn anchors_for(&self, reference_calendar_day: Date) -> WeatherPredictionAnchors {
        let training_end = reference_calendar_day;
        let training_start = Date::from_calendar_date(
            training_end.year().saturating_sub(20),
            time::Month::January,
            1,
        )
        .unwrap_or(training_end);
        WeatherPredictionAnchors {
            training_start_date: training_start,
            training_end_date: training_end,
        }
    }
}

struct StoreBackedWeatherPredictionService<'a> {
    store: &'a dyn PredictedWeatherStoreGateway,
}

impl FieldCultivationWeatherPredictionServiceGateway for StoreBackedWeatherPredictionService<'_> {
    fn predict_for_cultivation_plan(
        &self,
        _weather_location: &Value,
        _farm: &Value,
        plan_weather: &CultivationPlanWeatherInput,
    ) -> Option<Value> {
        if plan_weather.plan_metadata.is_none() {
            return None;
        }
        self.store
            .read_payload(PredictedWeatherScope::Plan, plan_weather.id)
            .ok()
            .flatten()
    }
}

#[derive(Deserialize)]
pub struct ClimateQuery {
    display_start_date: Option<String>,
    display_end_date: Option<String>,
}

fn status_for_message(message: &str) -> StatusCode {
    let m = message.to_lowercase();
    if m.contains("栽培期間") || m.contains("cultivation period") || m.contains("start_date") {
        return StatusCode::BAD_REQUEST;
    }
    if m.contains("not found")
        || m.contains("missing")
        || m.contains("weather")
        || m.contains("crop")
        || m.contains("field cultivation")
    {
        return StatusCode::NOT_FOUND;
    }
    StatusCode::INTERNAL_SERVER_ERROR
}

fn success_json(dto: FieldCultivationClimateDataOutput) -> Value {
    json!({
        "success": true,
        "field_cultivation": dto.field_cultivation,
        "farm": dto.farm,
        "crop_requirements": dto.crop_requirements,
        "weather_data": dto.weather_data,
        "gdd_data": dto.gdd_data,
        "stages": dto.stages,
    })
}

pub fn climate_routes(private: bool) -> Router<AppState> {
    if private {
        Router::new().route(
            "/api/v1/plans/field_cultivations/{id}/climate_data",
            axum::routing::get(private_climate_data),
        )
    } else {
        Router::new().route(
            "/api/v1/public_plans/field_cultivations/{id}/climate_data",
            axum::routing::get(public_climate_data),
        )
    }
}

async fn private_climate_data(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Query(query): Query<ClimateQuery>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"success": false, "message": "unauthorized"})),
        )
    })?;
    run_climate_data(&state, Some(user_id), id, query).await
}

async fn public_climate_data(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Query(query): Query<ClimateQuery>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    run_climate_data(&state, None, id, query).await
}

async fn run_climate_data(
    state: &AppState,
    user_id: Option<i64>,
    field_cultivation_id: i64,
    query: ClimateQuery,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let db_path = pool.database_path();
    let weather_bundle = WeatherDataGatewayBundle::resolve(pool.clone()).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": e.to_string()})),
        )
    })?;
    let weather_data =
        FieldCultivationWeatherDataFromStorageGateway::new(&weather_bundle);
    let climate_source = FieldCultivationClimateSourceSqliteGateway::new(db_path);
    let crop_gateway = FieldCultivationCropSqliteGateway::new(pool.clone());
    let plan_weather = FieldCultivationPlanPredictedWeatherSqliteGateway::from_bundle(
        pool.clone(),
        &state.predicted_weather,
    );
    let agrr = FieldCultivationClimateAgrrGateway::from_env();
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let logger = NoopLogger;
    let translator = PassthroughTranslator;
    let clock = SystemClock;
    let anchors = FixedAnchors;
    let prediction_service = StoreBackedWeatherPredictionService {
        store: state.predicted_weather.store.as_ref(),
    };

    let mut presenter = ClimatePresenter { body: None };
    let mut interactor = FieldCultivationClimateDataInteractor::new(
        &mut presenter,
        &logger,
        user_id,
        if user_id.is_some() {
            Some(&user_lookup as &dyn agrr_domain::shared::gateways::UserLookupGateway)
        } else {
            None
        },
        &climate_source,
        &crop_gateway,
        &weather_data,
        &prediction_service,
        &agrr,
        &plan_weather,
        state.predicted_weather.store.as_ref(),
        &anchors,
        &agrr,
        &clock,
        &translator,
    );

    let input = FieldCultivationClimateDataInput {
        field_cultivation_id,
        display_start_date: query.display_start_date,
        display_end_date: query.display_end_date,
    };
    interactor.call(input).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": e.to_string()})),
        )
    })?;

    match presenter.body {
        Some(ClimateOutcome::Success(dto)) => Ok(Json(success_json(dto))),
        Some(ClimateOutcome::Error(msg)) => Err((
            status_for_message(&msg),
            Json(json!({"success": false, "message": msg})),
        )),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "message": "no response"})),
        )),
    }
}
