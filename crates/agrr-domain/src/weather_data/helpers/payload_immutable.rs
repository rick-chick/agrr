//! Ruby: `Domain::WeatherData::PayloadImmutable`

use serde_json::Value;

/// Deep-clone JSON value for immutable DTO storage.
pub fn copy_and_deep_freeze(value: Option<Value>) -> Option<Value> {
    value.map(deep_clone_json)
}

fn deep_clone_json(value: Value) -> Value {
    match value {
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => value,
        Value::Array(items) => Value::Array(items.into_iter().map(deep_clone_json).collect()),
        Value::Object(map) => Value::Object(
            map.into_iter()
                .map(|(k, v)| (k, deep_clone_json(v)))
                .collect(),
        ),
    }
}
