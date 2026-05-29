//! Ruby: `Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper`

use serde_json::{json, Value};

/// Ruby: `Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper`
pub struct AdjustHistoricalPredictionMapper;

impl AdjustHistoricalPredictionMapper {
    pub fn build_historical_agrr_series(
        latitude: f64,
        longitude: f64,
        elevation: f64,
        timezone: &str,
        rows: &[Value],
    ) -> Value {
        let data: Vec<Value> = rows
            .iter()
            .filter_map(|row| {
                let tmax = row_value(row, "temperature_max")?;
                let tmin = row_value(row, "temperature_min")?;
                let temp_mean = row_value(row, "temperature_mean").unwrap_or((tmax + tmin) / 2.0);
                let day = row_value_string(row, "date")?;
                Some(json!({
                    "time": day,
                    "temperature_2m_max": tmax,
                    "temperature_2m_min": tmin,
                    "temperature_2m_mean": temp_mean,
                    "precipitation_sum": row_value(row, "precipitation").unwrap_or(0.0),
                    "sunshine_duration": Self::sunshine_duration_seconds(row),
                    "wind_speed_10m_max": row_value(row, "wind_speed").unwrap_or(0.0),
                    "weather_code": row_value(row, "weather_code").map(|v| v as i64).unwrap_or(0),
                }))
            })
            .collect();

        json!({
            "latitude": latitude,
            "longitude": longitude,
            "elevation": elevation,
            "timezone": timezone,
            "data": data,
        })
    }

    pub fn merge_historical_series_with_prediction(
        historical_series: &Value,
        prediction_data: &Value,
    ) -> Value {
        let pred = prediction_data
            .get("data")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let hist_data = historical_series
            .get("data")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let mut merged = hist_data;
        merged.extend(pred);
        json!({
            "latitude": historical_series["latitude"].clone(),
            "longitude": historical_series["longitude"].clone(),
            "elevation": historical_series["elevation"].clone(),
            "timezone": historical_series["timezone"].clone(),
            "data": merged,
        })
    }

    fn sunshine_duration_seconds(row: &Value) -> f64 {
        row_value(row, "sunshine_hours")
            .map(|h| h * 3600.0)
            .unwrap_or(0.0)
    }
}

fn row_value(row: &Value, key: &str) -> Option<f64> {
    row.get(key)
        .or_else(|| row.get(key))
        .and_then(|v| match v {
            Value::Number(n) => n.as_f64(),
            _ => None,
        })
}

fn row_value_string(row: &Value, key: &str) -> Option<String> {
    row.get(key).and_then(|v| {
        if let Some(s) = v.as_str() {
            Some(s.to_string())
        } else {
            None
        }
    })
}

#[cfg(test)]
mod mappers_adjust_historical_prediction_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/mappers_adjust_historical_prediction_mapper_test.rs"));
}
