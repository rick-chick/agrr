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
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn build_historical_agrr_series_skips_rows_missing_temperatures_and_formats_agrr_points() {
        let rows = vec![
            json!({
                "date": "2025-06-01",
                "temperature_max": 30.0,
                "temperature_min": 10.0,
                "precipitation": 1.5,
                "sunshine_hours": 2.0,
                "wind_speed": 3.0,
                "weather_code": 1
            }),
            json!({
                "date": "2025-06-02",
                "temperature_max": null,
                "temperature_min": 10.0
            }),
            json!({
                "date": "2025-06-03",
                "temperature_max": 20.0,
                "temperature_min": 12.0,
                "temperature_mean": 18.0
            }),
        ];

        let series = AdjustHistoricalPredictionMapper::build_historical_agrr_series(
            35.5,
            140.1,
            10.0,
            "Asia/Tokyo",
            &rows,
        );

        assert_eq!(series["latitude"], 35.5);
        assert_eq!(series["longitude"], 140.1);
        assert_eq!(series["elevation"], 10.0);
        assert_eq!(series["timezone"], "Asia/Tokyo");
        assert_eq!(series["data"].as_array().map(|a| a.len()), Some(2));

        let p0 = &series["data"][0];
        assert_eq!(p0["time"], "2025-06-01");
        assert!((p0["temperature_2m_max"].as_f64().unwrap() - 30.0).abs() < f64::EPSILON);
        assert!((p0["temperature_2m_min"].as_f64().unwrap() - 10.0).abs() < f64::EPSILON);
        assert!((p0["temperature_2m_mean"].as_f64().unwrap() - 20.0).abs() < f64::EPSILON);
        assert!((p0["precipitation_sum"].as_f64().unwrap() - 1.5).abs() < f64::EPSILON);
        assert!((p0["sunshine_duration"].as_f64().unwrap() - 7200.0).abs() < f64::EPSILON);
        assert!((p0["wind_speed_10m_max"].as_f64().unwrap() - 3.0).abs() < f64::EPSILON);
        assert_eq!(p0["weather_code"], 1);

        let p1 = &series["data"][1];
        assert_eq!(p1["time"], "2025-06-03");
        assert!((p1["temperature_2m_mean"].as_f64().unwrap() - 18.0).abs() < f64::EPSILON);
    }

    #[test]
    fn merge_historical_series_with_prediction_concatenates_data_arrays() {
        let historical_series = json!({
            "latitude": 1.0,
            "longitude": 2.0,
            "elevation": 3.0,
            "timezone": "UTC",
            "data": [ { "time": "2025-01-01" } ]
        });
        let prediction_data = json!({ "data": [ { "time": "2025-02-01" } ] });

        let merged = AdjustHistoricalPredictionMapper::merge_historical_series_with_prediction(
            &historical_series,
            &prediction_data,
        );

        assert_eq!(merged["latitude"], 1.0);
        assert_eq!(merged["data"].as_array().map(|a| a.len()), Some(2));
        assert_eq!(merged["data"][0]["time"], "2025-01-01");
        assert_eq!(merged["data"][1]["time"], "2025-02-01");
    }

    #[test]
    fn merge_historical_series_with_prediction_treats_missing_prediction_data_as_empty() {
        let historical_series = json!({
            "latitude": 1.0,
            "longitude": 2.0,
            "elevation": 3.0,
            "timezone": "UTC",
            "data": [ { "time": "2025-01-01" } ]
        });

        let merged = AdjustHistoricalPredictionMapper::merge_historical_series_with_prediction(
            &historical_series,
            &json!({}),
        );

        assert_eq!(merged["data"].as_array().map(|a| a.len()), Some(1));
    }
}
