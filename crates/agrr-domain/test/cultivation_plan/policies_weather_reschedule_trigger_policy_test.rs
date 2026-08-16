// Tests for `policies/weather_reschedule_trigger_policy.rs`.

use time::Date;

use crate::cultivation_plan::policies::plan_variance_threshold_policy::DEFAULT_GDD_THRESHOLD;
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    classify_all_triggers, frost_forecast_triggers, forecast_sudden_change_triggers,
    gdd_track_delay_triggers, ForecastDay, GddTrackPoint, ScheduledTaskForTrigger,
    WeatherRescheduleTriggerKind, DEFAULT_FORECAST_TEMPERATURE_CHANGE_THRESHOLD,
};

fn date(y: i32, m: u8, d: u8) -> Date {
    Date::from_calendar_date(y, time::Month::try_from(m).unwrap(), d).unwrap()
}

fn forecast_day(y: i32, m: u8, d: u8, t_min: f64) -> ForecastDay {
    ForecastDay {
        date: date(y, m, d),
        t_min,
    }
}

fn scheduled_task(item_id: i64, field_id: i64, y: i32, m: u8, d: u8) -> ScheduledTaskForTrigger {
    ScheduledTaskForTrigger {
        item_id,
        field_cultivation_id: field_id,
        scheduled_date: date(y, m, d),
    }
}

fn gdd_point(y: i32, m: u8, d: u8, planned: f64, actual: f64) -> GddTrackPoint {
    GddTrackPoint {
        date: date(y, m, d),
        planned_cumulative_gdd: planned,
        actual_cumulative_gdd: actual,
    }
}

#[test]
fn frost_forecast_when_t_min_below_threshold_and_task_scheduled_on_day() {
    let triggers = frost_forecast_triggers(
        0.0,
        &[forecast_day(2026, 3, 10, -2.0)],
        &[scheduled_task(1, 100, 2026, 3, 10)],
    );
    assert_eq!(1, triggers.len());
    assert_eq!(WeatherRescheduleTriggerKind::FrostForecast, triggers[0].kind);
    assert_eq!(Some(1), triggers[0].item_id);
    assert_eq!(Some(100), triggers[0].field_cultivation_id);
    assert_eq!(Some(date(2026, 3, 10)), triggers[0].date);
}

#[test]
fn frost_forecast_none_when_t_min_above_threshold() {
    let triggers = frost_forecast_triggers(
        0.0,
        &[forecast_day(2026, 3, 10, 1.0)],
        &[scheduled_task(1, 100, 2026, 3, 10)],
    );
    assert!(triggers.is_empty());
}

#[test]
fn frost_forecast_none_when_no_task_on_frost_day() {
    let triggers = frost_forecast_triggers(
        0.0,
        &[forecast_day(2026, 3, 10, -2.0)],
        &[scheduled_task(1, 100, 2026, 3, 11)],
    );
    assert!(triggers.is_empty());
}

#[test]
fn gdd_track_delay_when_deviation_exceeds_threshold() {
    let triggers = gdd_track_delay_triggers(
        &[gdd_point(2026, 4, 1, 100.0, 112.0)],
        DEFAULT_GDD_THRESHOLD,
    );
    assert_eq!(1, triggers.len());
    assert_eq!(WeatherRescheduleTriggerKind::GddTrackDelay, triggers[0].kind);
    assert_eq!(Some(date(2026, 4, 1)), triggers[0].date);
}

#[test]
fn gdd_track_delay_none_when_within_threshold() {
    let triggers = gdd_track_delay_triggers(
        &[gdd_point(2026, 4, 1, 100.0, 105.0)],
        DEFAULT_GDD_THRESHOLD,
    );
    assert!(triggers.is_empty());
}

#[test]
fn gdd_track_delay_negative_deviation() {
    let triggers = gdd_track_delay_triggers(
        &[gdd_point(2026, 4, 1, 100.0, 88.0)],
        DEFAULT_GDD_THRESHOLD,
    );
    assert_eq!(1, triggers.len());
    assert_eq!(WeatherRescheduleTriggerKind::GddTrackDelay, triggers[0].kind);
}

#[test]
fn forecast_sudden_change_when_t_min_delta_exceeds_threshold() {
    let current = [forecast_day(2026, 3, 10, -5.0)];
    let previous = [forecast_day(2026, 3, 10, -1.0)];
    let triggers = forecast_sudden_change_triggers(
        &current,
        &previous,
        DEFAULT_FORECAST_TEMPERATURE_CHANGE_THRESHOLD,
    );
    assert_eq!(1, triggers.len());
    assert_eq!(WeatherRescheduleTriggerKind::ForecastSuddenChange, triggers[0].kind);
    assert_eq!(Some(date(2026, 3, 10)), triggers[0].date);
}

#[test]
fn forecast_sudden_change_none_when_delta_within_threshold() {
    let current = [forecast_day(2026, 3, 10, 2.0)];
    let previous = [forecast_day(2026, 3, 10, 1.0)];
    let triggers = forecast_sudden_change_triggers(
        &current,
        &previous,
        DEFAULT_FORECAST_TEMPERATURE_CHANGE_THRESHOLD,
    );
    assert!(triggers.is_empty());
}

#[test]
fn classify_all_triggers_combines_three_kinds() {
    let triggers = classify_all_triggers(
        Some(0.0),
        &[forecast_day(2026, 3, 10, -2.0)],
        &[scheduled_task(1, 100, 2026, 3, 10)],
        &[gdd_point(2026, 4, 1, 100.0, 115.0)],
        &[forecast_day(2026, 3, 10, 5.0)],
    );
    let kinds: Vec<WeatherRescheduleTriggerKind> = triggers.iter().map(|t| t.kind).collect();
    assert!(kinds.contains(&WeatherRescheduleTriggerKind::FrostForecast));
    assert!(kinds.contains(&WeatherRescheduleTriggerKind::GddTrackDelay));
    assert!(kinds.contains(&WeatherRescheduleTriggerKind::ForecastSuddenChange));
}
