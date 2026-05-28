//! Ruby: `Domain::CultivationPlan::Normalizers::EntryScheduleWeatherPayloadNormalizer`

use serde_json::Value;

use crate::shared::hash::{blank, present};
use crate::shared::helpers::deep_dup;

/// Ruby: `EntryScheduleWeatherPayloadNormalizer.call`
pub fn call(raw: Option<&Value>) -> Value {
    let mut h = match raw {
        Some(v) if v.is_object() => deep_dup(v),
        _ => Value::Object(serde_json::Map::new()),
    };
    h = deep_stringify_keys(&h);

    if let Value::Object(ref mut map) = h {
        if let Some(Value::Object(inner_obj)) = map.get("data").cloned() {
            if inner_obj.get("data").map(|v| v.is_array()).unwrap_or(false) {
                let inner = deep_stringify_keys(&Value::Object(inner_obj));
                if let Value::Object(inner_map) = inner {
                    if let Some(data) = inner_map.get("data") {
                        map.insert("data".into(), data.clone());
                    }
                    for key in ["latitude", "longitude", "elevation", "timezone"] {
                        let outer_blank = map
                            .get(key)
                            .map(|v| blank(v))
                            .unwrap_or(true);
                        if outer_blank {
                            if let Some(v) = inner_map.get(key) {
                                if present(v) {
                                    map.insert(key.into(), v.clone());
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    h
}

fn deep_stringify_keys(obj: &Value) -> Value {
    match obj {
        Value::Object(map) => {
            let mut result = serde_json::Map::new();
            for (k, v) in map {
                result.insert(k.clone(), deep_stringify_keys(v));
            }
            Value::Object(result)
        }
        Value::Array(arr) => Value::Array(arr.iter().map(deep_stringify_keys).collect()),
        other => other.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn sample_rows() -> Vec<Value> {
        (1..=3)
            .map(|d| {
                json!({
                    "time": format!("2026-05-{d:02}"),
                    "temperature_2m_min": 8.0,
                    "temperature_2m_max": 22.0,
                    "temperature_2m_mean": 15.0
                })
            })
            .collect()
    }

    // Ruby: test "flattens nested data.data shape"
    #[test]
    fn flattens_nested_data_data_shape() {
        let rows = sample_rows();
        let nested = json!({
            "data": {
                "data": rows,
                "latitude": 35.5,
                "longitude": 139.7
            },
            "prediction_end_date": "2026-12-31"
        });

        let out = call(Some(&nested));
        let obj = out.as_object().expect("object");
        assert!(obj.get("data").expect("data").is_array());
        assert_eq!(obj.get("data").unwrap().as_array().unwrap().len(), 3);
        let lat = obj.get("latitude").unwrap().as_f64().unwrap();
        let lon = obj.get("longitude").unwrap().as_f64().unwrap();
        assert!((lat - 35.5).abs() < 0.001);
        assert!((lon - 139.7).abs() < 0.001);
    }

    // Ruby: test "leaves flat payload unchanged"
    #[test]
    fn leaves_flat_payload_unchanged() {
        let rows = sample_rows();
        let flat = json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "data": rows
        });
        let out = call(Some(&flat));
        let obj = out.as_object().expect("object");
        assert_eq!(obj.get("data").unwrap().as_array().unwrap().len(), 3);
        let lat = obj.get("latitude").unwrap().as_f64().unwrap();
        assert!((lat - 35.0).abs() < 0.001);
    }
}
