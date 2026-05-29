//! AttrMap → SQL column helpers for master CRUD gateways.

use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::exceptions::RecordInvalidError;
use rusqlite::types::Value;

pub fn attr_str(map: &AttrMap, key: &str) -> Option<String> {
    match map.get(key) {
        Some(AttrValue::Str(s)) if !s.is_empty() => Some(s.clone()),
        _ => None,
    }
}

pub fn attr_bool(map: &AttrMap, key: &str) -> Option<bool> {
    map.get(key).and_then(|v| match v {
        AttrValue::Bool(b) => Some(*b),
        _ => None,
    })
}

pub fn attr_f64(map: &AttrMap, key: &str) -> Option<f64> {
    map.get(key).and_then(|v| match v {
        AttrValue::Int(i) => Some(*i as f64),
        _ => None,
    })
}

pub fn attr_i64(map: &AttrMap, key: &str) -> Option<i64> {
    map.get(key).and_then(|v| match v {
        AttrValue::Int(i) => Some(*i),
        _ => None,
    })
}

pub fn require_str(map: &AttrMap, key: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    attr_str(map, key).ok_or_else(|| {
        Box::new(RecordInvalidError::new(
            Some(format!("{key} is required")),
            None,
        )) as Box<dyn std::error::Error + Send + Sync>
    })
}

pub fn sql_value_from_attr(v: &AttrValue) -> Value {
    match v {
        AttrValue::Null => Value::Null,
        AttrValue::Bool(b) => Value::Integer(if *b { 1 } else { 0 }),
        AttrValue::Int(i) => Value::Integer(*i),
        AttrValue::Str(s) => Value::Text(s.clone()),
    }
}
