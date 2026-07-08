//! Maps GDD progress JSON and weather payloads for task schedule generation.

use rust_decimal::Decimal;
use time::Date;

use crate::agricultural_task::task_schedule_sync_error::TaskScheduleSyncError;
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;
use crate::shared::helpers::deep_dup;
use crate::shared::type_converters::cast_big_decimal_json;

#[derive(Debug, Clone)]
pub struct ProgressRecord {
    pub date: String,
    pub cumulative_gdd: Option<Decimal>,
}

pub fn weather_data_present(data: &serde_json::Value) -> bool {
    !data.is_null() && data.as_object().is_some_and(|o| !o.is_empty())
        || data.as_array().is_some_and(|a| !a.is_empty())
}

pub fn progress_records_from_json(data: &serde_json::Value) -> Vec<ProgressRecord> {
    data.get("progress_records")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|record| {
                    let date = record.get("date")?.as_str()?.to_string();
                    let cumulative_gdd = cast_big_decimal_json(record.get("cumulative_gdd"));
                    Some(ProgressRecord {
                        date,
                        cumulative_gdd,
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

pub fn date_for_gdd(
    progress_records: &[ProgressRecord],
    target_gdd: Decimal,
    fallback_date: Option<Date>,
    crop_id: i64,
) -> Result<Date, Box<dyn std::error::Error + Send + Sync>> {
    for record in progress_records {
        if let Some(cumulative) = record.cumulative_gdd {
            if cumulative >= target_gdd {
                return safe_parse_date(&record.date).ok_or_else(|| {
                    Box::new(TaskScheduleSyncError::with_crop_id(
                        sync_errors::GDD_DATE_NOT_FOUND,
                        format!("no date for gdd {}", target_gdd),
                        crop_id,
                    )) as Box<dyn std::error::Error + Send + Sync>
                });
            }
        }
    }
    if let Some(fallback) = fallback_date {
        return Ok(fallback);
    }
    Err(Box::new(TaskScheduleSyncError::with_crop_id(
        sync_errors::GDD_DATE_NOT_FOUND,
        format!("no date for gdd {}", target_gdd),
        crop_id,
    )))
}

pub fn safe_parse_date(value: &str) -> Option<Date> {
    let trimmed = value.trim();
    if trimmed.len() < 10 {
        return None;
    }
    let date_part = &trimmed[..10];
    let parts: Vec<&str> = date_part.split('-').collect();
    if parts.len() != 3 {
        return None;
    }
    let year: i32 = parts[0].parse().ok()?;
    let month_num: u8 = parts[1].parse().ok()?;
    let day: u8 = parts[2].parse().ok()?;
    let month = time::Month::try_from(month_num).ok()?;
    Date::from_calendar_date(year, month, day).ok()
}

pub fn filtered_weather_data(weather_data: &serde_json::Value, start_date: Option<Date>) -> serde_json::Value {
    let Some(start_date) = start_date else {
        return weather_data.clone();
    };
    let Some(_obj) = weather_data.as_object() else {
        return weather_data.clone();
    };

    let mut duplicated = deep_dup(weather_data);
    let data_array = duplicated
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let filtered: Vec<serde_json::Value> = data_array
        .into_iter()
        .filter(|entry| {
            entry
                .get("time")
                .and_then(|v| v.as_str())
                .and_then(safe_parse_date)
                .map(|d| d >= start_date)
                .unwrap_or(false)
        })
        .collect();

    if !filtered.is_empty() {
        if let Some(obj) = duplicated.as_object_mut() {
            obj.insert("data".into(), serde_json::Value::Array(filtered));
        }
    }

    duplicated
}

#[cfg(test)]
mod task_schedule_progress_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/task_schedule_progress_mapper_test.rs"
    ));
}
