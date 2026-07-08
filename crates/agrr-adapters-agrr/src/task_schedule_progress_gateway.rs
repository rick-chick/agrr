//! agrr daemon progress for task schedule generation (`ProgressGateway`).

use std::sync::Arc;

use agrr_domain::agricultural_task::TaskScheduleSyncError;
use agrr_domain::agricultural_task::mappers::task_schedule_progress_failure_mapper::progress_unavailable_sync_error;
use agrr_domain::agricultural_task::task_schedule_sync_error_keys as sync_errors;
use agrr_domain::agricultural_task::gateways::{
    ProgressGateway, TaskScheduleCrop, TaskScheduleGenerationReadGateway,
};
use agrr_domain::field_cultivation::gateways::FieldCultivationClimateProgressGateway;
use serde_json::Value;
use time::Date;

use crate::field_cultivation_climate_gateway::FieldCultivationClimateAgrrGateway;

pub struct TaskScheduleProgressAgrrGateway {
    climate: FieldCultivationClimateAgrrGateway,
    read_gateway: Arc<dyn TaskScheduleGenerationReadGateway>,
}

impl TaskScheduleProgressAgrrGateway {
    pub fn new(
        climate: FieldCultivationClimateAgrrGateway,
        read_gateway: Arc<dyn TaskScheduleGenerationReadGateway>,
    ) -> Self {
        Self {
            climate,
            read_gateway,
        }
    }

    pub fn from_env(read_gateway: Arc<dyn TaskScheduleGenerationReadGateway>) -> Self {
        Self::new(
            FieldCultivationClimateAgrrGateway::from_env(),
            read_gateway,
        )
    }
}

fn progress_gateway_error(message: &str) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(progress_unavailable_sync_error(message))
}

impl ProgressGateway for TaskScheduleProgressAgrrGateway {
    fn calculate_progress(
        &self,
        crop: &TaskScheduleCrop,
        start_date: Option<Date>,
        weather_data: &Value,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let crop_requirement = self.read_gateway.build_crop_agrr_requirement(crop.id)?;
        let start_date = start_date.ok_or_else(|| {
            Box::new(TaskScheduleSyncError::new(
                sync_errors::MISSING_START_DATE,
                "start date is required for progress calculation",
            )) as Box<dyn std::error::Error + Send + Sync>
        })?;
        self.climate
            .calculate_progress(&crop_requirement, start_date, weather_data)
            .map_err(|err| progress_gateway_error(&err.to_string()))
    }
}
