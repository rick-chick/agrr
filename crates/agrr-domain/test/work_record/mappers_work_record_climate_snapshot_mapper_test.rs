use super::*;
use serde_json::json;
use time::macros::date;

#[test]
fn gdd_at_actual_from_progress_uses_latest_on_or_before_actual_date() {
    let progress = json!({
        "progress_records": [
            { "date": "2026-06-01", "cumulative_gdd": 50.0 },
            { "date": "2026-06-10", "cumulative_gdd": 120.5 },
            { "date": "2026-06-15", "cumulative_gdd": 200.0 }
        ]
    });
    let actual = date!(2026 - 06 - 12);
    assert_eq!(Some(120.5), gdd_at_actual_from_progress(&progress, actual));
}

#[test]
fn gdd_at_actual_from_progress_returns_none_when_no_records() {
    let progress = json!({ "progress_records": [] });
    let actual = date!(2026 - 06 - 12);
    assert_eq!(None, gdd_at_actual_from_progress(&progress, actual));
}

#[test]
fn weather_snapshot_for_date_picks_latest_on_or_before_actual_date() {
    let records = vec![
        json!({
            "date": "2026-06-01",
            "temperature_max": 20.0,
            "temperature_min": 10.0,
            "temperature_mean": 15.0
        }),
        json!({
            "date": "2026-06-10",
            "temperature_max": 28.0,
            "temperature_min": 18.0,
            "temperature_mean": 23.0
        }),
    ];
    let actual = date!(2026 - 06 - 12);
    let snapshot = weather_snapshot_for_date(&records, actual).expect("snapshot");
    assert_eq!("2026-06-10", snapshot["date"].as_str().unwrap());
    assert_eq!(23.0, snapshot["temperature_mean"].as_f64().unwrap());
}
