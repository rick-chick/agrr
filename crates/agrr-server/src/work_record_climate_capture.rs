//! Capture GDD and weather snapshot for work records using field cultivation climate stack.

use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_adapters_sqlite::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    WeatherDataGatewayBundle,
};
use agrr_domain::field_cultivation::gateways::{
    FieldCultivationClimateProgressGateway, FieldCultivationClimateSourceGateway,
    FieldCultivationCropGateway,
};
use agrr_domain::field_cultivation::mappers::{
    climate_crop_agrr_requirement_from_entity, extract_weather_records, to_context_snapshot,
};
use agrr_domain::field_cultivation::policies::{
    missing_cultivation_period, missing_weather_location,
};
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use agrr_domain::work_record::gateways::{
    WorkRecordClimateSnapshot, WorkRecordClimateSnapshotGateway,
};
use agrr_domain::work_record::mappers::{
    gdd_at_actual_from_progress, weather_snapshot_for_date,
};
use serde_json::Value;
use time::Date;

use crate::state::AppState;

pub struct WorkRecordClimateSnapshotGatewayImpl {
    climate_source: FieldCultivationClimateSourceSqliteGateway,
    crop_gateway: FieldCultivationCropSqliteGateway,
    progress_gateway: FieldCultivationClimateAgrrGateway,
    predicted_weather_store: std::sync::Arc<dyn PredictedWeatherStoreGateway>,
}

impl WorkRecordClimateSnapshotGatewayImpl {
    pub fn from_state(state: &AppState) -> Result<Self, String> {
        let pool = state.sqlite.clone();
        let db_path = pool.database_path();
        let _ = WeatherDataGatewayBundle::resolve(pool.clone()).map_err(|e| e.to_string())?;
        let store = state.predicted_weather.store.clone();
        Ok(Self {
            climate_source: FieldCultivationClimateSourceSqliteGateway::new(db_path),
            crop_gateway: FieldCultivationCropSqliteGateway::new(pool),
            progress_gateway: FieldCultivationClimateAgrrGateway::from_env(),
            predicted_weather_store: store,
        })
    }

    fn load_weather_payload(&self, plan_id: i64, plan_metadata_present: bool) -> Option<Value> {
        if !plan_metadata_present {
            return None;
        }
        self.predicted_weather_store
            .read_payload(PredictedWeatherScope::Plan, plan_id)
            .ok()
            .flatten()
    }
}

impl WorkRecordClimateSnapshotGateway for WorkRecordClimateSnapshotGatewayImpl {
    fn capture_at_date(
        &self,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<Option<WorkRecordClimateSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        let source = match self
            .climate_source
            .find_climate_source_snapshot_by_field_cultivation_id(field_cultivation_id)
        {
            Ok(snapshot) => snapshot,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => return Ok(None),
            Err(err) => return Err(err),
        };

        if missing_weather_location(source.weather_location_id)
            || missing_cultivation_period(source.start_date, source.completion_date)
        {
            return Ok(None);
        }

        let crop_id = match source.plan_crop_crop_id {
            Some(id) => id,
            None => return Ok(None),
        };
        let crop_entity = match self.crop_gateway.find_by_id(crop_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => return Ok(None),
            Err(err) => return Err(err),
        };

        let context = to_context_snapshot(&source, &crop_entity);
        let weather_payload = self.load_weather_payload(
            source.plan_id,
            context.plan_predicted_weather_present,
        );
        let Some(weather_payload) = weather_payload else {
            return Ok(None);
        };

        let weather_records = extract_weather_records(
            Some(&weather_payload),
            context.start_date,
            context.completion_date,
        );
        let weather_snapshot = weather_snapshot_for_date(&weather_records, actual_date);

        let crop_requirement = climate_crop_agrr_requirement_from_entity(&crop_entity);
        let progress_result = self
            .progress_gateway
            .calculate_progress(&crop_requirement, context.start_date, &weather_payload)
            .unwrap_or_else(|_| Value::Null);
        let gdd_at_actual = if progress_result.is_null() {
            None
        } else {
            gdd_at_actual_from_progress(&progress_result, actual_date)
        };

        if gdd_at_actual.is_none() && weather_snapshot.is_none() {
            return Ok(None);
        }

        Ok(Some(WorkRecordClimateSnapshot {
            gdd_at_actual,
            weather_snapshot,
        }))
    }
}

pub fn work_record_climate_snapshot_gateway(
    state: &AppState,
) -> Result<WorkRecordClimateSnapshotGatewayImpl, String> {
    WorkRecordClimateSnapshotGatewayImpl::from_state(state)
}
