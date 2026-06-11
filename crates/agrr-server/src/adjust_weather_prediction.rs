//! Ruby: `AdjustWeatherPredictionActiveRecordGateway` — WeatherPredictionInteractor wiring for adjust/add_crop.

use agrr_adapters_agrr::PredictionDaemonGateway;
use agrr_adapters_sqlite::{SqlitePool, WeatherDataGatewayBundle};
use agrr_domain::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, WeatherPredictionService,
};
use agrr_domain::weather_data::dtos::{CultivationPlanWeather, WeatherLocation};
use agrr_domain::shared::ports::LoggerPort;
use agrr_domain::weather_data::gateways::{
    PredictedWeatherMetadataGateway, PredictedWeatherStoreGateway,
};
use agrr_domain::weather_data::helpers::normalize_nested_weather_data;
use agrr_domain::weather_data::interactors::WeatherPredictionInteractor;
use agrr_domain::weather_data::WeatherPredictionError;
use serde_json::Value;
use std::sync::Arc;
use time::Date;

use crate::adapters::{StderrLogger, SystemClock};
use crate::state::AppState;
use crate::weather_prediction_anchors::SystemWeatherPredictionAnchors;

#[derive(Clone)]
pub struct SqliteAdjustWeatherPredictionGateway {
    pool: SqlitePool,
    metadata: Arc<dyn PredictedWeatherMetadataGateway>,
    store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl SqliteAdjustWeatherPredictionGateway {
    pub fn new(
        pool: SqlitePool,
        metadata: Arc<dyn PredictedWeatherMetadataGateway>,
        store: Arc<dyn PredictedWeatherStoreGateway>,
    ) -> Self {
        Self {
            pool,
            metadata,
            store,
        }
    }

    pub fn from_state(state: &AppState) -> Self {
        Self::new(
            state.sqlite.clone(),
            state.predicted_weather.metadata.clone(),
            state.predicted_weather.store.clone(),
        )
    }
}

impl AdjustWeatherPredictionGateway for SqliteAdjustWeatherPredictionGateway {
    fn prediction_service(
        &self,
        weather_location: &WeatherLocation,
    ) -> Result<Box<dyn WeatherPredictionService>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Box::new(OwnedWeatherPredictionService {
            weather_location: weather_location.clone(),
            logger: StderrLogger,
            metadata: self.metadata.clone(),
            store: self.store.clone(),
            weather_gateway: WeatherDataGatewayBundle::resolve(self.pool.clone())
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?,
            prediction_gateway: PredictionDaemonGateway::from_env(),
            clock: SystemClock,
            anchors: SystemWeatherPredictionAnchors,
        }))
    }
}

struct OwnedWeatherPredictionService {
    weather_location: WeatherLocation,
    logger: StderrLogger,
    metadata: Arc<dyn PredictedWeatherMetadataGateway>,
    store: Arc<dyn PredictedWeatherStoreGateway>,
    weather_gateway: WeatherDataGatewayBundle,
    prediction_gateway: PredictionDaemonGateway,
    clock: SystemClock,
    anchors: SystemWeatherPredictionAnchors,
}

impl OwnedWeatherPredictionService {
    fn with_interactor<R>(
        &self,
        f: impl FnOnce(&WeatherPredictionInteractor<'_>) -> R,
    ) -> Result<R, WeatherPredictionError> {
        let interactor = WeatherPredictionInteractor::new(
            self.weather_location.clone(),
            self.metadata.as_ref(),
            self.store.as_ref(),
            &self.weather_gateway,
            &self.prediction_gateway,
            &self.logger,
            &self.clock,
            &self.anchors,
        )?;
        Ok(f(&interactor))
    }
}

impl WeatherPredictionService for OwnedWeatherPredictionService {
    fn get_existing_prediction(
        &self,
        target_end_date: Date,
        cultivation_plan_weather: &CultivationPlanWeather,
    ) -> Option<Value> {
        self.with_interactor(|interactor| {
            interactor
                .get_existing_prediction(
                    Some(target_end_date),
                    Some(cultivation_plan_weather),
                )
                .map(|r| normalize_nested_weather_data(r.data))
        })
        .ok()
        .flatten()
    }

    fn predict_for_cultivation_plan(
        &self,
        cultivation_plan_weather: &CultivationPlanWeather,
        target_end_date: Option<Date>,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.with_interactor(|interactor| {
            interactor
                .predict_for_cultivation_plan(cultivation_plan_weather, target_end_date)
                .map(|info| normalize_nested_weather_data(info.data))
        })
        .and_then(|r| r)
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }
}

/// Rails optimize: `get_existing_prediction` → `weather_info[:data]` (+ normalize).
pub fn existing_prediction_weather_for_allocate(
    state: &AppState,
    weather_location: &WeatherLocation,
    plan_weather: &CultivationPlanWeather,
    planning_end_date: Date,
) -> Result<Value, String> {
    let gateway = SqliteAdjustWeatherPredictionGateway::from_state(state);
    let service = gateway
        .prediction_service(weather_location)
        .map_err(|e| e.to_string())?;
    let weather = service
        .get_existing_prediction(planning_end_date, plan_weather)
        .ok_or_else(|| {
            "天気予測データが存在しません。計画作成時に天気予測が実行されていません。".to_string()
        })?;
    let days = weather
        .get("data")
        .and_then(|d| d.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    if days == 0 {
        return Err(
            "天気予測データが存在しません（data 行が空）。計画作成時に天気予測を実行してください。"
                .into(),
        );
    }
    Ok(weather)
}

/// Ruby CompositionRoot `weather_for_candidates` lambda (add_crop candidates).
pub(crate) fn resolve_weather_for_candidates(
    state: &AppState,
    plan_id: i64,
    plan_weather: &CultivationPlanWeather,
    target_end_date: Date,
    logger: &StderrLogger,
) -> Result<Value, WeatherPredictionError> {
    let weather_location = crate::cultivation_plan_weather_load::load_weather_location(
        &state.sqlite,
        plan_id,
    )
    .map_err(|_| WeatherPredictionError::WeatherLocationRequired)?;

    let gateway = SqliteAdjustWeatherPredictionGateway::from_state(state);
    let service = gateway
        .prediction_service(&weather_location)
        .map_err(|e| WeatherPredictionError::InsufficientPredictionData(e.to_string()))?;

    logger.info(&format!(
        "🔍 [Candidates] Weather target end date: {target_end_date}"
    ));

    let mut weather_data = if let Some(existing) =
        service.get_existing_prediction(target_end_date, plan_weather)
    {
        logger.info(&format!(
            "📡 [Candidates] WeatherPredictionInteractor cache hit (target_end_date={target_end_date})"
        ));
        existing
    } else {
        logger.info(&format!(
            "📡 [Candidates] WeatherPredictionInteractor cache miss - invoking prediction (target_end_date={target_end_date})"
        ));
        service
            .predict_for_cultivation_plan(plan_weather, Some(target_end_date))
            .map_err(|e| {
                e.downcast::<WeatherPredictionError>()
                    .map(|boxed| *boxed)
                    .unwrap_or_else(|e| {
                        WeatherPredictionError::InsufficientPredictionData(e.to_string())
                    })
            })?
    };

    normalize_weather_payload_for_agrr(&mut weather_data, logger)
}

fn normalize_weather_payload_for_agrr(
    weather_data: &mut Value,
    logger: &StderrLogger,
) -> Result<Value, WeatherPredictionError> {
    *weather_data = normalize_nested_weather_data(weather_data.clone());

    let days = weather_data
        .get("data")
        .and_then(|d| d.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    logger.info(&format!(
        "📡 [Candidates] WeatherPredictionInteractor result: days={days}"
    ));

    if days == 0 {
        return Err(WeatherPredictionError::InsufficientPredictionData(
            "weather payload has no data rows".into(),
        ));
    }

    Ok(weather_data.clone())
}
