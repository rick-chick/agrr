//! Work record climate snapshot gateway — composes field cultivation climate stack.

use std::sync::Arc;

use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_adapters_sqlite::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    FieldCultivationPlanPredictedWeatherSqliteGateway,
    FieldCultivationWeatherDataFromStorageGateway,
    UserLookupSqliteGateway, WeatherDataGatewayBundle,
};
use agrr_domain::field_cultivation::dtos::{
    CultivationPlanWeatherInput, FieldCultivationClimateDataInput,
    FieldCultivationClimateDataOutput,
};
use agrr_domain::field_cultivation::gateways::FieldCultivationWeatherPredictionServiceGateway;
use agrr_domain::field_cultivation::interactors::FieldCultivationClimateDataInteractor;
use agrr_domain::field_cultivation::ports::{
    FieldCultivationClimateDataInputPort, FieldCultivationClimateDataOutputPort,
    WeatherPredictionAnchors, WeatherPredictionAnchorsPort,
};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use agrr_domain::work_record::gateways::WorkRecordClimateSnapshotGateway;
use agrr_domain::work_record::mappers::work_record_climate_snapshot_mapper::{
    snapshot_from_climate_output, WorkRecordClimateSnapshot,
};
use serde_json::Value;
use time::Date;

use crate::adapters::{NoopLogger, PassthroughTranslator, SystemClock};
use crate::state::AppState;

struct CollectingClimatePresenter {
    body: Option<FieldCultivationClimateDataOutput>,
    errored: bool,
}

impl FieldCultivationClimateDataOutputPort for CollectingClimatePresenter {
    fn present(&mut self, data: FieldCultivationClimateDataOutput) {
        self.body = Some(data);
    }

    fn on_error(&mut self, _error: Error) {
        self.errored = true;
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

struct StoreBackedWeatherPredictionService {
    store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl FieldCultivationWeatherPredictionServiceGateway for StoreBackedWeatherPredictionService {
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

pub struct WorkRecordClimateSnapshotGatewayImpl<'a> {
    state: &'a AppState,
}

impl<'a> WorkRecordClimateSnapshotGatewayImpl<'a> {
    pub fn new(state: &'a AppState) -> Self {
        Self { state }
    }
}

impl WorkRecordClimateSnapshotGateway for WorkRecordClimateSnapshotGatewayImpl<'_> {
    fn snapshot_for_field_cultivation(
        &self,
        user_id: i64,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let pool = self.state.sqlite.clone();
        let db_path = pool.database_path();
        let weather_bundle = WeatherDataGatewayBundle::resolve(pool.clone())?;
        let weather_data = FieldCultivationWeatherDataFromStorageGateway::new(&weather_bundle);
        let climate_source = FieldCultivationClimateSourceSqliteGateway::new(db_path);
        let crop_gateway = FieldCultivationCropSqliteGateway::new(pool.clone());
        let plan_weather = FieldCultivationPlanPredictedWeatherSqliteGateway::from_bundle(
            pool.clone(),
            &self.state.predicted_weather,
        );
        let agrr = FieldCultivationClimateAgrrGateway::from_env();
        let user_lookup = UserLookupSqliteGateway::new(pool);
        let logger = NoopLogger;
        let translator = PassthroughTranslator;
        let clock = SystemClock;
        let anchors = FixedAnchors;
        let prediction_service = StoreBackedWeatherPredictionService {
            store: self.state.predicted_weather.store.clone(),
        };

        let mut presenter = CollectingClimatePresenter {
            body: None,
            errored: false,
        };
        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut presenter,
            &logger,
            Some(user_id),
            Some(&user_lookup),
            &climate_source,
            &crop_gateway,
            &weather_data,
            &prediction_service,
            &agrr,
            &plan_weather,
            self.state.predicted_weather.store.as_ref(),
            &anchors,
            &agrr,
            &clock,
            &translator,
        );

        let input = FieldCultivationClimateDataInput {
            field_cultivation_id,
            display_start_date: None,
            display_end_date: None,
        };
        interactor.call(input)?;

        if presenter.errored || presenter.body.is_none() {
            return Ok(WorkRecordClimateSnapshot::empty());
        }

        Ok(snapshot_from_climate_output(
            presenter.body.as_ref().expect("climate output"),
            actual_date,
        ))
    }
}
