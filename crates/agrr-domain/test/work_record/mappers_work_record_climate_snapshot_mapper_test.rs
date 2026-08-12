// Tests for `mappers/work_record_climate_snapshot_mapper.rs`

use crate::field_cultivation::dtos::FieldCultivationClimateDataOutput;
use crate::work_record::mappers::work_record_climate_snapshot_mapper::{
    gdd_at_actual_for_date, snapshot_from_climate_output, weather_snapshot_for_date,
};
use serde_json::json;
use time::macros::date;

#[test]
fn gdd_at_actual_for_date_returns_cumulative_gdd_on_match() {
    let daily_gdd = vec![
        json!({"date": "2026-06-10", "cumulative_gdd": 50.0}),
        json!({"date": "2026-06-12", "cumulative_gdd": 120.5}),
    ];
    assert_eq!(
        Some(120.5),
        gdd_at_actual_for_date(&daily_gdd, date!(2026-06-12))
    );
}

#[test]
fn gdd_at_actual_for_date_returns_none_when_date_missing() {
    let daily_gdd = vec![json!({"date": "2026-06-10", "cumulative_gdd": 50.0})];
    assert_eq!(None, gdd_at_actual_for_date(&daily_gdd, date!(2026-06-12)));
}

#[test]
fn weather_snapshot_for_date_returns_single_day_payload() {
    let weather_data = vec![json!({
        "date": "2026-06-12",
        "temperature_max": 28.0,
        "temperature_min": 18.0,
        "temperature_mean": 23.0,
    })];
    let snapshot = weather_snapshot_for_date(&weather_data, date!(2026-06-12)).unwrap();
    assert_eq!("2026-06-12", snapshot["date"].as_str().unwrap());
    assert_eq!(28.0, snapshot["temperature_max"].as_f64().unwrap());
    assert_eq!(18.0, snapshot["temperature_min"].as_f64().unwrap());
    assert_eq!(23.0, snapshot["temperature_mean"].as_f64().unwrap());
}

#[test]
fn snapshot_from_climate_output_extracts_both_fields() {
    let output = FieldCultivationClimateDataOutput {
        field_cultivation: json!({}),
        farm: json!({}),
        crop_requirements: json!({}),
        weather_data: vec![json!({
            "date": "2026-06-12",
            "temperature_max": 28.0,
            "temperature_min": 18.0,
            "temperature_mean": 23.0,
        })],
        gdd_data: vec![json!({"date": "2026-06-12", "cumulative_gdd": 120.5})],
        stages: vec![],
        progress_result: json!({}),
        debug_info: json!({}),
    };
    let snapshot = snapshot_from_climate_output(&output, date!(2026-06-12));
    assert_eq!(Some(120.5), snapshot.gdd_at_actual);
    assert!(snapshot.weather_snapshot.is_some());
    assert_eq!(
        "2026-06-12",
        snapshot.weather_snapshot.unwrap()["date"].as_str().unwrap()
    );
}
