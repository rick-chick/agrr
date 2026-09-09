//! Orchestrates entry-schedule weather payload preparation:
//! normalize → enrich from location → unwrap nested data → validate non-empty rows.

use std::fmt;

use serde_json::Value;

use crate::weather_data::dtos::WeatherLocation;
use crate::weather_data::helpers::normalize_nested_weather_data;

use super::entry_schedule_weather_location_enricher;
use super::entry_schedule_weather_payload_normalizer;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EntryScheduleWeatherPrepareError {
    EmptyDataRows,
}

impl fmt::Display for EntryScheduleWeatherPrepareError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyDataRows => f.write_str("weather payload has no data rows"),
        }
    }
}

impl std::error::Error for EntryScheduleWeatherPrepareError {}

/// Normalizes, enriches coordinates from `location`, and rejects empty `data` rows.
pub fn prepare(mut payload: Value, location: &WeatherLocation) -> Result<Value, EntryScheduleWeatherPrepareError> {
    payload = entry_schedule_weather_payload_normalizer::call(Some(&payload));
    entry_schedule_weather_location_enricher::enrich_from_location(&mut payload, location);
    payload = normalize_nested_weather_data(payload);

    let days = payload
        .get("data")
        .and_then(|d| d.as_array())
        .map(|a| a.len())
        .unwrap_or(0);

    if days == 0 {
        return Err(EntryScheduleWeatherPrepareError::EmptyDataRows);
    }

    Ok(payload)
}

#[cfg(test)]
mod normalizers_entry_schedule_weather_preparer_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/normalizers_entry_schedule_weather_preparer_test.rs"
    ));
}
