//! AttrMap → SQL column helpers for master CRUD gateways.

use std::borrow::Cow;

use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::exceptions::RecordInvalidError;
use rusqlite::types::Value;

/// Quote column names that collide with SQLite reserved words.
pub fn quote_sql_column(name: &str) -> Cow<'_, str> {
    if name.eq_ignore_ascii_case("order") {
        Cow::Borrowed("\"order\"")
    } else {
        Cow::Borrowed(name)
    }
}

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
        // Domain interactors store floats as strings (Ruby parity).
        AttrValue::Str(s) => s.parse::<f64>().ok(),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quote_sql_column_quotes_order() {
        assert_eq!(quote_sql_column("order"), "\"order\"");
        assert_eq!(quote_sql_column("ORDER"), "\"order\"");
        assert_eq!(quote_sql_column("name"), "name");
    }

    #[test]
    fn attr_f64_reads_int_and_string_values() {
        use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};

        let from_int = attr_map_from_pairs([("n", AttrValue::Int(15))]);
        assert_eq!(attr_f64(&from_int, "n"), Some(15.0));

        let from_str = attr_map_from_pairs([("n", AttrValue::Str("12.5".into()))]);
        assert_eq!(attr_f64(&from_str, "n"), Some(12.5));

        let missing = attr_map_from_pairs([("n", AttrValue::Str("not-a-number".into()))]);
        assert_eq!(attr_f64(&missing, "n"), None);
    }
}
