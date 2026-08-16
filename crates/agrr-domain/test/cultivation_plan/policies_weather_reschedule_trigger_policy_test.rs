// Tests for `policies/weather_reschedule_trigger_policy.rs`.

use time::{Date, Month};

use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    classify_forecast_sudden_change_triggers, classify_frost_forecast_triggers,
    classify_gdd_trajectory_delay_triggers, WeatherForecastDay, WeatherRescheduleTaskSchedule,
    WeatherRescheduleTriggerKind, DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD,
    DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD,
};
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    GddTrajectorySample,
};

fn date(y: i32, m: u8, d: u8) -> Date {
    Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap()
}

#[test]
fn frost_forecast_trigger_when_t_min_below_threshold_on_task_date() {
    let forecast = vec![WeatherForecastDay {
        date: date(2026, 4, 10),
        t_min: -2.0,
        t_mean: Some(5.0),
    }];
    let tasks = vec![WeatherRescheduleTaskSchedule {
        item_id: 42,
        field_cultivation_id: 100,
        scheduled_date: date(2026, 4, 10),
    }];

    let triggers = classify_frost_forecast_triggers(&forecast, Some(0.0), &tasks);

    assert_eq!(triggers.len(), 1);
    assert_eq!(
        triggers[0].kind,
        WeatherRescheduleTriggerKind::FrostForecast
    );
    assert_eq!(triggers[0].field_cultivation_id, 100);
    assert_eq!(triggers[0].item_id, Some(42));
    assert_eq!(triggers[0].trigger_date, Some(date(2026, 4, 10)));
    assert_eq!(triggers[0].forecast_t_min, Some(-2.0));
    assert_eq!(triggers[0].frost_threshold, Some(0.0));
}

#[test]
fn frost_forecast_skipped_when_t_min_above_threshold() {
    let forecast = vec![WeatherForecastDay {
        date: date(2026, 4, 10),
        t_min: 3.0,
        t_mean: Some(8.0),
    }];
    let tasks = vec![WeatherRescheduleTaskSchedule {
        item_id: 42,
        field_cultivation_id: 100,
        scheduled_date: date(2026, 4, 10),
    }];

    let triggers = classify_frost_forecast_triggers(&forecast, Some(0.0), &tasks);

    assert!(triggers.is_empty());
}

#[test]
fn frost_forecast_skipped_when_task_date_does_not_overlap_forecast_day() {
    let forecast = vec![WeatherForecastDay {
        date: date(2026, 4, 10),
        t_min: -2.0,
        t_mean: Some(5.0),
    }];
    let tasks = vec![WeatherRescheduleTaskSchedule {
        item_id: 42,
        field_cultivation_id: 100,
        scheduled_date: date(2026, 4, 11),
    }];

    let triggers = classify_frost_forecast_triggers(&forecast, Some(0.0), &tasks);

    assert!(triggers.is_empty());
}

#[test]
fn gdd_trajectory_delay_trigger_when_delta_exceeds_threshold() {
    let samples = vec![GddTrajectorySample {
        field_cultivation_id: 200,
        reference_date: date(2026, 5, 1),
        cumulative_gdd_actual: 80.0,
        cumulative_gdd_planned: 100.0,
    }];

    let triggers =
        classify_gdd_trajectory_delay_triggers(&samples, DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD);

    assert_eq!(triggers.len(), 1);
    assert_eq!(
        triggers[0].kind,
        WeatherRescheduleTriggerKind::GddTrajectoryDelay
    );
    assert_eq!(triggers[0].field_cultivation_id, 200);
    assert_eq!(triggers[0].gdd_delta, Some(20.0));
}

#[test]
fn gdd_trajectory_delay_skipped_when_within_threshold() {
    let samples = vec![GddTrajectorySample {
        field_cultivation_id: 200,
        reference_date: date(2026, 5, 1),
        cumulative_gdd_actual: 95.0,
        cumulative_gdd_planned: 100.0,
    }];

    let triggers =
        classify_gdd_trajectory_delay_triggers(&samples, DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD);

    assert!(triggers.is_empty());
}

#[test]
fn forecast_sudden_change_trigger_when_t_min_delta_exceeds_threshold() {
    let previous = vec![WeatherForecastDay {
        date: date(2026, 4, 15),
        t_min: 8.0,
        t_mean: Some(14.0),
    }];
    let current = vec![WeatherForecastDay {
        date: date(2026, 4, 15),
        t_min: 2.0,
        t_mean: Some(8.0),
    }];

    let triggers = classify_forecast_sudden_change_triggers(
        &previous,
        &current,
        DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD,
    );

    assert_eq!(triggers.len(), 1);
    assert_eq!(
        triggers[0].kind,
        WeatherRescheduleTriggerKind::ForecastSuddenChange
    );
    assert_eq!(triggers[0].trigger_date, Some(date(2026, 4, 15)));
    assert_eq!(triggers[0].forecast_t_min_delta, Some(6.0));
}

#[test]
fn forecast_sudden_change_skipped_when_delta_within_threshold() {
    let previous = vec![WeatherForecastDay {
        date: date(2026, 4, 15),
        t_min: 8.0,
        t_mean: Some(14.0),
    }];
    let current = vec![WeatherForecastDay {
        date: date(2026, 4, 15),
        t_min: 7.0,
        t_mean: Some(13.0),
    }];

    let triggers = classify_forecast_sudden_change_triggers(
        &previous,
        &current,
        DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD,
    );

    assert!(triggers.is_empty());
}
