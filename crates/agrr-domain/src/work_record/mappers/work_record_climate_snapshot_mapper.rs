//! Extract work-record climate snapshot from field cultivation climate output.

use serde_json::Value;
use time::Date;

use crate::field_cultivation::dtos::FieldCultivationClimateDataOutput;
use crate::field_cultivation::helpers::parse_iso_date;
use crate::work_record::dtos::WorkRecordClimateSnapshot;

pub fn snapshot_from_climate_output(
    output: &FieldCultivationClimateDataOutput,
    actual_date: Date,
) -> WorkRecordClimateSnapshot {
    let gdd_at_actual = gdd_for_date(&output.gdd_data, actual_date);
    let weather_snapshot = weather_row_for_date(&output.weather_data, actual_date);
    WorkRecordClimateSnapshot {
        gdd_at_actual,
        weather_snapshot,
    }
}

fn gdd_for_date(gdd_data: &[Value], actual_date: Date) -> Option<f64> {
    let mut last: Option<f64> = None;
    for datum in gdd_data {
        let Some(datum_date) = datum_date(datum) else {
            continue;
        };
        if datum_date > actual_date {
            break;
        }
        if let Some(cumulative) = datum.get("cumulative_gdd").and_then(|v| v.as_f64()) {
            last = Some(cumulative);
        }
        if datum_date == actual_date {
            return last;
        }
    }
    last
}

fn weather_row_for_date(weather_data: &[Value], actual_date: Date) -> Option<Value> {
    weather_data
        .iter()
        .find(|datum| datum_date(datum) == Some(actual_date))
        .cloned()
}

fn datum_date(datum: &Value) -> Option<Date> {
    let date_str = datum.get("date")?.as_str()?;
    parse_iso_date(date_str)
}

#[cfg(test)]
mod work_record_climate_snapshot_mapper_test_inline {
    use super::*;
    use serde_json::json;
    use time::macros::date;

    #[test]
    fn extracts_gdd_and_weather_for_actual_date() {
        let output = FieldCultivationClimateDataOutput {
            field_cultivation: json!({}),
            farm: json!({}),
            crop_requirements: json!({}),
            weather_data: vec![
                json!({
                    "date": "2026-06-10",
                    "temperature_max": 28.0,
                    "temperature_min": 18.0,
                    "temperature_mean": 23.0,
                }),
                json!({
                    "date": "2026-06-12",
                    "temperature_max": 30.0,
                    "temperature_min": 20.0,
                    "temperature_mean": 25.0,
                }),
            ],
            gdd_data: vec![
                json!({ "date": "2026-06-10", "cumulative_gdd": 120.5 }),
                json!({ "date": "2026-06-12", "cumulative_gdd": 145.25 }),
            ],
            stages: vec![],
            progress_result: json!({}),
            debug_info: json!({}),
        };

        let snapshot = snapshot_from_climate_output(&output, date!(2026-06-12));
        assert_eq!(Some(145.25), snapshot.gdd_at_actual);
        assert_eq!(
            Some(json!({
                "date": "2026-06-12",
                "temperature_max": 30.0,
                "temperature_min": 20.0,
                "temperature_mean": 25.0,
            })),
            snapshot.weather_snapshot
        );
    }

    #[test]
    fn uses_last_gdd_on_or_before_actual_date_when_exact_day_missing() {
        let output = FieldCultivationClimateDataOutput {
            field_cultivation: json!({}),
            farm: json!({}),
            crop_requirements: json!({}),
            weather_data: vec![],
            gdd_data: vec![
                json!({ "date": "2026-06-10", "cumulative_gdd": 100.0 }),
                json!({ "date": "2026-06-11", "cumulative_gdd": 110.0 }),
            ],
            stages: vec![],
            progress_result: json!({}),
            debug_info: json!({}),
        };

        let snapshot = snapshot_from_climate_output(&output, date!(2026-06-12));
        assert_eq!(Some(110.0), snapshot.gdd_at_actual);
        assert!(snapshot.weather_snapshot.is_none());
    }
}
