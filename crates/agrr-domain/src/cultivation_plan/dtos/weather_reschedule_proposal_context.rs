//! Internal read context for weather-triggered reschedule proposal generation.

use std::collections::HashMap;

use time::Date;

use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    GddTrajectorySample, WeatherForecastDay, WeatherRescheduleTaskSchedule,
};

/// Field cultivation snapshot for rationale and move generation.
#[derive(Debug, Clone, PartialEq)]
pub struct WeatherRescheduleCultivationSnapshot {
    pub field_cultivation_id: i64,
    pub plan_field_id: i64,
    pub start_date: Option<Date>,
    pub completion_date: Option<Date>,
    pub crop_name: String,
    pub field_name: String,
    pub frost_threshold: Option<f64>,
}

/// Loaded plan context for classifying triggers and building proposals.
#[derive(Debug, Clone, PartialEq)]
pub struct WeatherRescheduleProposalContext {
    pub tasks: Vec<WeatherRescheduleTaskSchedule>,
    pub current_forecast: Vec<WeatherForecastDay>,
    pub previous_forecast: Vec<WeatherForecastDay>,
    pub gdd_samples: Vec<GddTrajectorySample>,
    pub cultivations: Vec<WeatherRescheduleCultivationSnapshot>,
}

impl WeatherRescheduleProposalContext {
    pub fn cultivation_by_id(&self, field_cultivation_id: i64) -> Option<&WeatherRescheduleCultivationSnapshot> {
        self.cultivations
            .iter()
            .find(|row| row.field_cultivation_id == field_cultivation_id)
    }

    pub fn frost_threshold_by_cultivation(&self) -> HashMap<i64, f64> {
        self.cultivations
            .iter()
            .filter_map(|row| {
                row.frost_threshold
                    .map(|threshold| (row.field_cultivation_id, threshold))
            })
            .collect()
    }
}
