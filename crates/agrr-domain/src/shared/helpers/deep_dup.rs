//! Ruby: `Domain::Shared::DeepDup`

use serde_json::Value;

/// Deep-clone JSON trees (Hash / Array); strings are copied, scalars are cloned.
pub fn deep_dup(value: &Value) -> Value {
    match value {
        Value::Object(map) => {
            let mut out = serde_json::Map::new();
            for (k, v) in map {
                out.insert(k.clone(), deep_dup(v));
            }
            Value::Object(out)
        }
        Value::Array(arr) => Value::Array(arr.iter().map(deep_dup).collect()),
        Value::String(s) => Value::String(s.clone()),
        Value::Number(n) => Value::Number(n.clone()),
        Value::Bool(b) => Value::Bool(*b),
        Value::Null => Value::Null,
    }
}

#[cfg(test)]
mod helpers_deep_dup_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/helpers_deep_dup_test.rs"));
}
