//! Classifies weather-based reschedule triggers for proactive adjust proposals.
//!
//! Three trigger kinds:
//! - Frost forecast: forecast `t_min` below `frost_threshold` on a scheduled task date
//! - GDD trajectory delay: cumulative GDD deviates from planned trajectory beyond threshold
//! - Forecast sudden change: forecast `t_min` changed significantly since previous fetch

use time::Date;

use crate::cultivation_plan::policies::plan_variance_threshold_policy::DEFAULT_GDD_THRESHOLD;

/// Default absolute `t_min` delta (°C) between forecast fetches to flag sudden change.
pub const DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD: f64 = 3.0;

/// Reuses plan-vs-actual GDD exceedance threshold for trajectory delay detection.
pub const DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD: f64 = DEFAULT_GDD_THRESHOLD;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WeatherRescheduleTriggerKind {
    FrostForecast,
    GddTrajectoryDelay,
    ForecastSuddenChange,
}

impl WeatherRescheduleTriggerKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::FrostForecast => "frost_forecast",
            Self::GddTrajectoryDelay => "gdd_trajectory_delay",
            Self::ForecastSuddenChange => "forecast_sudden_change",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherForecastDay {
    pub date: Date,
    pub t_min: f64,
    pub t_mean: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherRescheduleTaskSchedule {
    pub item_id: i64,
    pub field_cultivation_id: i64,
    pub scheduled_date: Date,
}

#[derive(Debug, Clone, PartialEq)]
pub struct GddTrajectorySample {
    pub field_cultivation_id: i64,
    pub reference_date: Date,
    pub cumulative_gdd_actual: f64,
    pub cumulative_gdd_planned: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherRescheduleTrigger {
    pub kind: WeatherRescheduleTriggerKind,
    pub field_cultivation_id: i64,
    pub item_id: Option<i64>,
    pub trigger_date: Option<Date>,
    pub forecast_t_min: Option<f64>,
    pub frost_threshold: Option<f64>,
    pub gdd_delta: Option<f64>,
    pub forecast_t_min_delta: Option<f64>,
}

/// Detects frost-forecast triggers when forecast `t_min` is below threshold on a task date.
pub fn classify_frost_forecast_triggers(
    forecast: &[WeatherForecastDay],
    frost_threshold: Option<f64>,
    tasks: &[WeatherRescheduleTaskSchedule],
) -> Vec<WeatherRescheduleTrigger> {
    let Some(frost_threshold) = frost_threshold else {
        return vec![];
    };

    let mut triggers = Vec::new();
    for task in tasks {
        let Some(day) = forecast.iter().find(|row| row.date == task.scheduled_date) else {
            continue;
        };
        if day.t_min >= frost_threshold {
            continue;
        }
        triggers.push(WeatherRescheduleTrigger {
            kind: WeatherRescheduleTriggerKind::FrostForecast,
            field_cultivation_id: task.field_cultivation_id,
            item_id: Some(task.item_id),
            trigger_date: Some(day.date),
            forecast_t_min: Some(day.t_min),
            frost_threshold: Some(frost_threshold),
            gdd_delta: None,
            forecast_t_min_delta: None,
        });
    }
    triggers
}

/// Detects GDD trajectory delay when cumulative GDD deviates from planned beyond threshold.
pub fn classify_gdd_trajectory_delay_triggers(
    samples: &[GddTrajectorySample],
    threshold: f64,
) -> Vec<WeatherRescheduleTrigger> {
    samples
        .iter()
        .filter_map(|sample| {
            let delta = sample.cumulative_gdd_planned - sample.cumulative_gdd_actual;
            if delta.abs() <= threshold {
                return None;
            }
            Some(WeatherRescheduleTrigger {
                kind: WeatherRescheduleTriggerKind::GddTrajectoryDelay,
                field_cultivation_id: sample.field_cultivation_id,
                item_id: None,
                trigger_date: Some(sample.reference_date),
                forecast_t_min: None,
                frost_threshold: None,
                gdd_delta: Some(delta),
                forecast_t_min_delta: None,
            })
        })
        .collect()
}

/// Detects forecast sudden change when `t_min` delta between fetches exceeds threshold.
pub fn classify_forecast_sudden_change_triggers(
    previous_forecast: &[WeatherForecastDay],
    current_forecast: &[WeatherForecastDay],
    threshold: f64,
) -> Vec<WeatherRescheduleTrigger> {
    let mut triggers = Vec::new();
    for current in current_forecast {
        let Some(previous) = previous_forecast
            .iter()
            .find(|row| row.date == current.date)
        else {
            continue;
        };
        let delta = (current.t_min - previous.t_min).abs();
        if delta <= threshold {
            continue;
        }
        triggers.push(WeatherRescheduleTrigger {
            kind: WeatherRescheduleTriggerKind::ForecastSuddenChange,
            field_cultivation_id: 0,
            item_id: None,
            trigger_date: Some(current.date),
            forecast_t_min: Some(current.t_min),
            frost_threshold: None,
            gdd_delta: None,
            forecast_t_min_delta: Some(delta),
        });
    }
    triggers
}

#[cfg(test)]
mod policies_weather_reschedule_trigger_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_weather_reschedule_trigger_policy_test.rs"
    ));
}
