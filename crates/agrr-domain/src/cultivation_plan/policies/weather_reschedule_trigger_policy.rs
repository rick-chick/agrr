//! Classifies weather-based reschedule triggers: frost forecast, GDD track delay, forecast sudden change.

use time::Date;

use crate::cultivation_plan::policies::plan_variance_threshold_policy::DEFAULT_GDD_THRESHOLD;

/// Minimum absolute temperature change between forecast fetches to flag sudden change.
pub const DEFAULT_FORECAST_TEMPERATURE_CHANGE_THRESHOLD: f64 = 3.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WeatherRescheduleTriggerKind {
    FrostForecast,
    GddTrackDelay,
    ForecastSuddenChange,
}

impl WeatherRescheduleTriggerKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::FrostForecast => "frost_forecast",
            Self::GddTrackDelay => "gdd_track_delay",
            Self::ForecastSuddenChange => "forecast_sudden_change",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherRescheduleTrigger {
    pub kind: WeatherRescheduleTriggerKind,
    pub item_id: Option<i64>,
    pub field_cultivation_id: Option<i64>,
    pub date: Option<Date>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ScheduledTaskForTrigger {
    pub item_id: i64,
    pub field_cultivation_id: i64,
    pub scheduled_date: Date,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ForecastDay {
    pub date: Date,
    pub t_min: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct GddTrackPoint {
    pub date: Date,
    pub planned_cumulative_gdd: f64,
    pub actual_cumulative_gdd: f64,
}

/// Frost forecast: forecast `t_min` < `frost_threshold` and a task is scheduled on that day.
pub fn frost_forecast_triggers(
    frost_threshold: f64,
    forecast_days: &[ForecastDay],
    scheduled_tasks: &[ScheduledTaskForTrigger],
) -> Vec<WeatherRescheduleTrigger> {
    let mut triggers = Vec::new();

    for day in forecast_days {
        if day.t_min >= frost_threshold {
            continue;
        }
        for task in scheduled_tasks {
            if task.scheduled_date != day.date {
                continue;
            }
            triggers.push(WeatherRescheduleTrigger {
                kind: WeatherRescheduleTriggerKind::FrostForecast,
                item_id: Some(task.item_id),
                field_cultivation_id: Some(task.field_cultivation_id),
                date: Some(day.date),
            });
        }
    }

    triggers
}

/// GDD track delay: cumulative GDD deviates from the planned track beyond the threshold.
pub fn gdd_track_delay_triggers(
    track_points: &[GddTrackPoint],
    gdd_threshold: f64,
) -> Vec<WeatherRescheduleTrigger> {
    track_points
        .iter()
        .filter(|point| {
            (point.actual_cumulative_gdd - point.planned_cumulative_gdd).abs() > gdd_threshold
        })
        .map(|point| WeatherRescheduleTrigger {
            kind: WeatherRescheduleTriggerKind::GddTrackDelay,
            item_id: None,
            field_cultivation_id: None,
            date: Some(point.date),
        })
        .collect()
}

/// Forecast sudden change: same-day `t_min` differs from the previous fetch beyond threshold.
pub fn forecast_sudden_change_triggers(
    current_forecast: &[ForecastDay],
    previous_forecast: &[ForecastDay],
    temperature_change_threshold: f64,
) -> Vec<WeatherRescheduleTrigger> {
    let mut triggers = Vec::new();

    for current in current_forecast {
        let previous_t_min = previous_forecast
            .iter()
            .find(|prev| prev.date == current.date)
            .map(|prev| prev.t_min);

        if let Some(prev_t_min) = previous_t_min {
            if (current.t_min - prev_t_min).abs() > temperature_change_threshold {
                triggers.push(WeatherRescheduleTrigger {
                    kind: WeatherRescheduleTriggerKind::ForecastSuddenChange,
                    item_id: None,
                    field_cultivation_id: None,
                    date: Some(current.date),
                });
            }
        }
    }

    triggers
}

/// Classifies all three trigger kinds from the provided inputs.
pub fn classify_all_triggers(
    frost_threshold: Option<f64>,
    forecast_days: &[ForecastDay],
    scheduled_tasks: &[ScheduledTaskForTrigger],
    gdd_track_points: &[GddTrackPoint],
    previous_forecast: &[ForecastDay],
) -> Vec<WeatherRescheduleTrigger> {
    let mut triggers = Vec::new();

    if let Some(threshold) = frost_threshold {
        triggers.extend(frost_forecast_triggers(threshold, forecast_days, scheduled_tasks));
    }
    triggers.extend(gdd_track_delay_triggers(gdd_track_points, DEFAULT_GDD_THRESHOLD));
    triggers.extend(
        forecast_sudden_change_triggers(
            forecast_days,
            previous_forecast,
            DEFAULT_FORECAST_TEMPERATURE_CHANGE_THRESHOLD,
        ),
    );

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
