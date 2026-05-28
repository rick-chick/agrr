//! Ruby: `Domain::Shared` — `blank?`, `present?`, key conversion, `to_array`.

use std::collections::BTreeMap;

use serde_json::Value;

use crate::shared::attr::{AttrMap, AttrValue};

/// Ruby: `Domain::Shared.blank?`
pub fn blank(value: &Value) -> bool {
    match value {
        Value::Null => true,
        Value::Bool(false) => true,
        Value::Bool(true) => false,
        Value::String(s) => s.trim().is_empty(),
        Value::Array(a) => a.is_empty(),
        Value::Object(o) => o.is_empty(),
        _ => false,
    }
}

/// Ruby: `Domain::Shared.blank?` for [`AttrValue`].
pub fn blank_attr(value: &AttrValue) -> bool {
    match value {
        AttrValue::Null => true,
        AttrValue::Bool(false) => true,
        AttrValue::Bool(true) => false,
        AttrValue::Str(s) => s.trim().is_empty(),
        _ => false,
    }
}

/// Ruby: `Domain::Shared.present?`
pub fn present(value: &Value) -> bool {
    !blank(value)
}

pub fn present_attr(value: &AttrValue) -> bool {
    !blank_attr(value)
}

/// Ruby: `Domain::Shared.to_array`
pub fn to_array(value: Option<&Value>) -> Vec<Value> {
    match value {
        None | Some(Value::Null) => vec![],
        Some(Value::Array(a)) => a.clone(),
        Some(v) => vec![v.clone()],
    }
}

/// Ruby: `Domain::Shared.stringify_keys` (top level only).
pub fn stringify_keys(map: Option<&BTreeMap<String, Value>>) -> BTreeMap<String, Value> {
    let Some(map) = map else {
        return BTreeMap::new();
    };
    map.iter()
        .map(|(k, v)| (k.clone(), v.clone()))
        .collect()
}

/// Ruby: `Domain::Shared.symbolize_keys` — in Rust, keys are normalized `String`s (top level only).
pub fn symbolize_keys(map: Option<&BTreeMap<String, Value>>) -> AttrMap {
    let Some(map) = map else {
        return BTreeMap::new();
    };
    map.iter()
        .map(|(k, v)| (k.clone(), attr_value_from_json(v)))
        .collect()
}

/// Ruby: `Domain::Shared.deep_symbolize_keys`
pub fn deep_symbolize_keys(value: &Value) -> Value {
    match value {
        Value::Object(map) => {
            let mut out = serde_json::Map::new();
            for (k, v) in map {
                out.insert(k.clone(), deep_symbolize_keys(v));
            }
            Value::Object(out)
        }
        Value::Array(arr) => Value::Array(arr.iter().map(deep_symbolize_keys).collect()),
        other => other.clone(),
    }
}

fn attr_value_from_json(v: &Value) -> AttrValue {
    match v {
        Value::Null => AttrValue::Null,
        Value::Bool(b) => AttrValue::Bool(*b),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                AttrValue::Int(i)
            } else {
                AttrValue::Str(n.to_string())
            }
        }
        Value::String(s) => AttrValue::Str(s.clone()),
        _ => AttrValue::Str(v.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn blank_nil_and_false() {
        assert!(blank(&Value::Null));
        assert!(blank(&json!(false)));
    }

    #[test]
    fn blank_whitespace_string() {
        assert!(blank(&json!("   ")));
        assert!(!blank(&json!("test")));
    }

    #[test]
    fn present_is_inverse_of_blank() {
        assert!(present(&json!("test")));
        assert!(!present(&Value::Null));
    }

    #[test]
    fn to_array_nil_and_wrap() {
        assert_eq!(to_array(None), Vec::<Value>::new());
        assert_eq!(to_array(Some(&json!(1))), vec![json!(1)]);
        let arr = vec![json!(1), json!(2)];
        assert_eq!(to_array(Some(&Value::Array(arr.clone()))), arr);
    }

    #[test]
    fn deep_symbolize_keys_recurses() {
        let h = json!({ "outer": { "inner": [ { "x": 1 } ] } });
        let out = deep_symbolize_keys(&h);
        assert_eq!(out, h);
    }

    #[test]
    fn symbolize_keys_empty_for_none() {
        assert!(symbolize_keys(None).is_empty());
    }

    #[test]
    fn stringify_keys_top_level() {
        let mut map = BTreeMap::new();
        map.insert("a".into(), json!(1));
        map.insert("b".into(), json!(2));
        let out = stringify_keys(Some(&map));
        assert_eq!(out.get("a"), Some(&json!(1)));
        assert_eq!(out.get("b"), Some(&json!(2)));
    }

    #[test]
    fn blank_array_and_hash() {
        assert!(blank(&json!([])));
        assert!(blank(&json!({})));
        assert!(!blank(&json!([1])));
    }
}
