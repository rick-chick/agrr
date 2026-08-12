//! Work record climate snapshot via field cultivation climate interactor.

use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_adapters_sqlite::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    FieldCultivationPlanPredictedWeatherSqliteGateway,
    FieldCultivationWeatherDataFromStorageGateway, SqlitePool, WeatherDataGatewayBundle,
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
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use agrr_domain::work_record::dtos::WorkRecordClimateSnapshot;
use agrr_domain::work_record::gateways::WorkRecordClimateSnapshotGateway;
use agrr_domain::work_record::mappers::snapshot_from_climate_output;
use time::Date;

use crate::adapters::{NoopLogger, PassthroughTranslator, SystemClock};
use crate::state::AppState;

struct CaptureClimatePresenter {
    output: Option<FieldCultivationClimateDataOutput>,
}

impl FieldCultivationClimateDataOutputPort for CaptureClimatePresenter {
    fn present(&mut self, data: FieldCultivationClimateDataOutput) {
        self.output = Some(data);
    }

    fn on_error(&mut self, _error: Error) {}
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
        _weather_location: &serde_json::Value,
        _farm: &serde_json::Value,
        plan_weather: &CultivationPlanWeatherInput,
    ) -> Option<serde_json::Value> {
        if plan_weather.plan_metadata.is_none() {
            return None;
        }
        self.store
            .read_payload(PredictedWeatherScope::Plan, plan_weather.id)
            .ok()
            .flatten()
    }
}

pub struct WorkRecordClimateSnapshotService {
    pool: SqlitePool,
    predicted_weather: agrr_adapters_sqlite::PredictedWeatherGatewayBundle,
}

impl WorkRecordClimateSnapshotService {
    pub fn from_state(state: &AppState) -> Self {
        Self {
            pool: state.sqlite.clone(),
            predicted_weather: state.predicted_weather.clone(),
        }
    }
}

impl WorkRecordClimateSnapshotGateway for WorkRecordClimateSnapshotService {
    fn lookup(
        &self,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let pool = self.pool.clone();
        let db_path = pool.database_path();
        let weather_bundle = WeatherDataGatewayBundle::resolve(pool.clone())?;
        let weather_data = FieldCultivationWeatherDataFromStorageGateway::new(&weather_bundle);
        let climate_source = FieldCultivationClimateSourceSqliteGateway::new(db_path);
        let crop_gateway = FieldCultivationCropSqliteGateway::new(pool.clone());
        let plan_weather =
            FieldCultivationPlanPredictedWeatherSqliteGateway::from_bundle(
                pool.clone(),
                &self.predicted_weather,
            );
        let agrr = FieldCultivationClimateAgrrGateway::from_env();
        let logger = NoopLogger;
        let translator = PassthroughTranslator;
        let clock = SystemClock;
        let anchors = FixedAnchors;
        let prediction_service = StoreBackedWeatherPredictionService {
            store: self.predicted_weather.store.as_ref(),
        };

        let mut presenter = CaptureClimatePresenter { output: None };
        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut presenter,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &prediction_service,
            &agrr,
            &plan_weather,
            self.predicted_weather.store.as_ref(),
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

        if let Some(output) = presenter.output {
            return Ok(snapshot_from_climate_output(&output, actual_date));
        }
        Ok(WorkRecordClimateSnapshot::empty())
    }
}
