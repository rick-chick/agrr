//! Ruby: `Domain::Shared::TypeConverters::IntegerConverter`

use crate::shared::attr::AttrValue;

/// Cast agrr-style integer values (digit strings or integers only).
pub fn cast_integer(value: Option<&serde_json::Value>) -> Option<i64> {
    match value {
        None | Some(serde_json::Value::Null) => None,
        Some(serde_json::Value::Number(n)) => n.as_i64(),
        Some(serde_json::Value::String(s)) => cast_integer_str(s),
        _ => None,
    }
}

pub fn cast_integer_attr(value: &AttrValue) -> Option<i64> {
    match value {
        AttrValue::Int(i) => Some(*i),
        AttrValue::Str(s) => cast_integer_str(s),
        AttrValue::Null => None,
        _ => None,
    }
}

fn cast_integer_str(s: &str) -> Option<i64> {
    // Ruby: /\A-?\d+\z/
    let bytes = s.as_bytes();
    if bytes.is_empty() {
        return None;
    }
    let start = if bytes[0] == b'-' { 1 } else { 0 };
    if start == bytes.len() {
        return None;
    }
    if !bytes[start..].iter().all(|b| b.is_ascii_digit()) {
        return None;
    }
    s.parse().ok()
}

#[cfg(test)]
mod type_converters_integer_converter_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/type_converters_integer_converter_test.rs"));
}
