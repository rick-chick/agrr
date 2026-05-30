//! Ruby: `AdjustWeatherPredictionActiveRecordGateway` — WeatherPredictionInteractor wiring for adjust/add_crop.

use agrr_adapters_agrr::PredictionDaemonGateway;
use agrr_adapters_sqlite::{
    FieldCultivationPlanPredictedWeatherSqliteGateway, SqlitePool, WeatherDataSqliteGateway,
};
use agrr_domain::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, WeatherPredictionService,
};
use agrr_domain::weather_data::dtos::{
    CultivationPlanWeather, FarmWeatherPrediction, WeatherLocation,
};
use agrr_domain::shared::ports::LoggerPort;
use agrr_domain::weather_data::helpers::normalize_nested_weather_data;
use agrr_domain::weather_data::interactors::WeatherPredictionInteractor;
use agrr_domain::weather_data::WeatherPredictionError;
use serde_json::Value;
use time::Date;

use crate::adapters::{StderrLogger, SystemClock};
use crate::weather_prediction_anchors::SystemWeatherPredictionAnchors;

#[derive(Clone)]
pub struct SqliteAdjustWeatherPredictionGateway {
    pool: SqlitePool,
}

impl SqliteAdjustWeatherPredictionGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl AdjustWeatherPredictionGateway for SqliteAdjustWeatherPredictionGateway {
    fn prediction_service(
        &self,
        weather_location: &WeatherLocation,
        farm: Option<&FarmWeatherPrediction>,
    ) -> Result<Box<dyn WeatherPredictionService>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Box::new(OwnedWeatherPredictionService {
            weather_location: weather_location.clone(),
            logger: StderrLogger,
            farm_predicted: farm.and_then(|f| f.predicted_weather_data().cloned()),
            plan_gateway: FieldCultivationPlanPredictedWeatherSqliteGateway::new(self.pool.clone()),
            weather_gateway: WeatherDataSqliteGateway::new(self.pool.clone()),
            prediction_gateway: PredictionDaemonGateway::from_env(),
            clock: SystemClock,
            anchors: SystemWeatherPredictionAnchors,
        }))
    }
}

struct OwnedWeatherPredictionService {
    weather_location: WeatherLocation,
    logger: StderrLogger,
    farm_predicted: Option<Value>,
    plan_gateway: FieldCultivationPlanPredictedWeatherSqliteGateway,
    weather_gateway: WeatherDataSqliteGateway,
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
            &self.plan_gateway,
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
                    self.farm_predicted.as_ref(),
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
    pool: &SqlitePool,
    weather_location: &WeatherLocation,
    farm: Option<&FarmWeatherPrediction>,
    plan_weather: &CultivationPlanWeather,
    planning_end_date: Date,
) -> Result<Value, String> {
    let gateway = SqliteAdjustWeatherPredictionGateway::new(pool.clone());
    let service = gateway
        .prediction_service(weather_location, farm)
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
    pool: &SqlitePool,
    plan_id: i64,
    plan_weather: &CultivationPlanWeather,
    target_end_date: Date,
    logger: &StderrLogger,
) -> Result<Value, WeatherPredictionError> {
    use crate::cultivation_plan_weather_load::{load_farm_weather_prediction, load_weather_location};

    let weather_location = load_weather_location(pool, plan_id)
        .map_err(|_| WeatherPredictionError::WeatherLocationRequired)?;
    let farm = load_farm_weather_prediction(pool, plan_id).ok().flatten();

    let gateway = SqliteAdjustWeatherPredictionGateway::new(pool.clone());
    let service = gateway
        .prediction_service(&weather_location, farm.as_ref())
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
