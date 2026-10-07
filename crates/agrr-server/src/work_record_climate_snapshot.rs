//! Work record climate snapshot via field cultivation climate interactor.

use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_adapters_sqlite::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    FieldCultivationWeatherDataFromStorageGateway, SqlitePool, WeatherDataGatewayBundle,
};
use agrr_domain::field_cultivation::dtos::{
    FieldCultivationClimateDataInput, FieldCultivationClimateDataOutput,
};
use agrr_domain::field_cultivation::interactors::FieldCultivationClimateDataInteractor;
use agrr_domain::field_cultivation::ports::{
    FieldCultivationClimateDataInputPort, FieldCultivationClimateDataOutputPort,
};
use agrr_domain::field_cultivation::dtos::FieldCultivationClimateFailure;
use agrr_domain::shared::dtos::Error;
use agrr_domain::work_record::errors::WorkRecordClimateSnapshotUnavailableError;
use agrr_domain::work_record::dtos::WorkRecordClimateSnapshot;
use agrr_domain::work_record::gateways::WorkRecordClimateSnapshotGateway;
use agrr_domain::work_record::mappers::snapshot_from_climate_output;
use time::Date;

use crate::adapters::{PassthroughTranslator, StderrLogger, SystemClock};
use crate::state::AppState;

struct CaptureClimatePresenter {
    output: Option<FieldCultivationClimateDataOutput>,
    failure: Option<FieldCultivationClimateFailure>,
}

impl FieldCultivationClimateDataOutputPort for CaptureClimatePresenter {
    fn present(&mut self, data: FieldCultivationClimateDataOutput) {
        self.output = Some(data);
    }

    fn on_error(&mut self, _error: Error) {}

    fn on_failure(&mut self, failure: FieldCultivationClimateFailure) {
        self.failure = Some(failure);
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
        let agrr = FieldCultivationClimateAgrrGateway::from_env();
        let logger = StderrLogger;
        let translator = PassthroughTranslator;
        let clock = SystemClock;

        let mut presenter = CaptureClimatePresenter {
            output: None,
            failure: None,
        };
        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut presenter,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            self.predicted_weather.store.as_ref(),
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

        if let Some(failure) = presenter.failure {
            return Err(Box::new(WorkRecordClimateSnapshotUnavailableError::new(failure)));
        }

        if let Some(output) = presenter.output {
            return Ok(snapshot_from_climate_output(&output, actual_date));
        }
        Ok(WorkRecordClimateSnapshot::empty())
    }
}
