//! Extract GDD and weather snapshot at work-record actual_date from climate payloads.

use rust_decimal::prelude::ToPrimitive;
use serde_json::Value;
use time::Date;

use crate::agricultural_task::mappers::task_schedule_progress_mapper::{
    progress_records_from_json, safe_parse_date,
};
use crate::field_cultivation::helpers::parse_iso_date;

pub fn gdd_at_actual_from_progress(progress_result: &Value, actual_date: Date) -> Option<f64> {
    let records = progress_records_from_json(progress_result);
    let mut best: Option<(Date, f64)> = None;
    for record in records {
        let Some(record_date) = safe_parse_date(&record.date) else {
            continue;
        };
        if record_date > actual_date {
            continue;
        }
        let gdd = record
            .cumulative_gdd
            .and_then(|d| d.to_f64());
        if let Some(gdd_val) = gdd {
            if best.is_none() || record_date >= best.unwrap().0 {
                best = Some((record_date, gdd_val));
            }
        }
    }
    best.map(|(_, g)| g)
}

pub fn weather_snapshot_for_date(weather_records: &[Value], actual_date: Date) -> Option<Value> {
    let mut best: Option<(Date, Value)> = None;
    for datum in weather_records {
        let date_str = datum
            .get("date")
            .and_then(|v| v.as_str())
            .or_else(|| datum.get("time").and_then(|v| v.as_str()));
        let Some(date_str) = date_str else {
            continue;
        };
        let Some(datum_date) = parse_iso_date(date_str) else {
            continue;
        };
        if datum_date > actual_date {
            continue;
        }
        if best.is_none() || datum_date >= best.as_ref().unwrap().0 {
            best = Some((datum_date, datum.clone()));
        }
    }
    best.map(|(_, v)| v)
}

#[cfg(test)]
mod work_record_climate_snapshot_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/mappers_work_record_climate_snapshot_mapper_test.rs"
    ));
}
