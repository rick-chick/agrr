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
mod normalizers_entry_schedule_weather_payload_normalizer_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/normalizers_entry_schedule_weather_payload_normalizer_test.rs"));
}
