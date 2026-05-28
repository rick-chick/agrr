//! Convert plan-save mapper JSON attribute maps to domain `AttrMap`.

use std::collections::BTreeMap;

use serde_json::Value;

use crate::shared::attr::{AttrMap, AttrValue};

pub fn attr_map_from_json(map: BTreeMap<String, Value>) -> AttrMap {
    map.into_iter()
        .map(|(k, v)| (k, json_to_attr_value(v)))
        .collect()
}

fn json_to_attr_value(value: Value) -> AttrValue {
    match value {
        Value::Null => AttrValue::Null,
        Value::Bool(b) => AttrValue::Bool(b),
        Value::Number(n) => n
            .as_i64()
            .map(AttrValue::Int)
            .unwrap_or_else(|| AttrValue::Str(n.to_string())),
        Value::String(s) => AttrValue::Str(s),
        other => AttrValue::Str(other.to_string()),
    }
}
