//! Finalize weather payload for agrr: unwrap nested `data` and validate non-empty rows.

use std::fmt;

use serde_json::Value;

use super::normalize_nested_weather_data;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FinalizeWeatherPayloadError {
    EmptyDataRows,
}

impl fmt::Display for FinalizeWeatherPayloadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyDataRows => f.write_str("weather payload has no data rows"),
        }
    }
}

impl std::error::Error for FinalizeWeatherPayloadError {}

/// Unwraps nested weather `data` and rejects empty `data` rows.
pub fn finalize_weather_payload_for_agrr(
    payload: Value,
) -> Result<Value, FinalizeWeatherPayloadError> {
    let normalized = normalize_nested_weather_data(payload);

    let days = normalized
        .get("data")
        .and_then(|d| d.as_array())
        .map(|a| a.len())
        .unwrap_or(0);

    if days == 0 {
        return Err(FinalizeWeatherPayloadError::EmptyDataRows);
    }

    Ok(normalized)
}

#[cfg(test)]
mod helpers_finalize_weather_payload_for_agrr_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/helpers_finalize_weather_payload_for_agrr_test.rs"
    ));
}
