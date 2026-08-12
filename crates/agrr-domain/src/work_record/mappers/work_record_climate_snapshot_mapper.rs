//! Extract GDD and weather snapshot for a work record actual_date from climate chart data.

use serde_json::{json, Value};
use time::Date;

use crate::field_cultivation::helpers::parse_iso_date;
use crate::field_cultivation::dtos::FieldCultivationClimateDataOutput;

/// Snapshot values persisted on a work record.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordClimateSnapshot {
    pub gdd_at_actual: Option<f64>,
    pub weather_snapshot: Option<Value>,
}

impl WorkRecordClimateSnapshot {
    pub fn empty() -> Self {
        Self {
            gdd_at_actual: None,
            weather_snapshot: None,
        }
    }
}

/// Build snapshot from assembled field cultivation climate output.
pub fn snapshot_from_climate_output(
    output: &FieldCultivationClimateDataOutput,
    actual_date: Date,
) -> WorkRecordClimateSnapshot {
    WorkRecordClimateSnapshot {
        gdd_at_actual: gdd_at_actual_for_date(&output.gdd_data, actual_date),
        weather_snapshot: weather_snapshot_for_date(&output.weather_data, actual_date),
    }
}

/// Lookup baseline-adjusted cumulative GDD for `actual_date` from daily GDD chart data.
pub fn gdd_at_actual_for_date(daily_gdd: &[Value], actual_date: Date) -> Option<f64> {
    daily_gdd.iter().find_map(|datum| {
        let date_str = datum.get("date")?.as_str()?;
        let datum_date = parse_iso_date(date_str)?;
        if datum_date != actual_date {
            return None;
        }
        datum.get("cumulative_gdd").and_then(|v| v.as_f64())
    })
}

/// Build single-day weather snapshot JSON for `actual_date`.
pub fn weather_snapshot_for_date(weather_data: &[Value], actual_date: Date) -> Option<Value> {
    weather_data.iter().find_map(|datum| {
        let date_str = datum.get("date")?.as_str()?;
        let datum_date = parse_iso_date(date_str)?;
        if datum_date != actual_date {
            return None;
        }
        Some(json!({
            "date": date_str,
            "temperature_max": datum.get("temperature_max").cloned().unwrap_or(Value::Null),
            "temperature_min": datum.get("temperature_min").cloned().unwrap_or(Value::Null),
            "temperature_mean": datum.get("temperature_mean").cloned().unwrap_or(Value::Null),
        }))
    })
}

#[cfg(test)]
mod mappers_work_record_climate_snapshot_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/mappers_work_record_climate_snapshot_mapper_test.rs"
    ));
}
