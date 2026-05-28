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
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn distinct_nested_hashes_with_equal_content() {
        let original = json!({ "a": { "b": 1 }, "c": [1, 2] });
        let mut copy = deep_dup(&original);
        assert_eq!(original, copy);
        copy["a"]["b"] = json!(99);
        assert_eq!(original["a"]["b"], 1);
        assert_eq!(copy["a"]["b"], 99);
    }

    #[test]
    fn duplicates_strings_inside_hashes() {
        let original = json!({ "name": "x" });
        let copy = deep_dup(&original);
        let mut copy_s = copy["name"].as_str().unwrap().to_string();
        copy_s.push('y');
        assert_eq!(original["name"], "x");
    }

    #[test]
    fn leaves_nil_and_booleans() {
        assert_eq!(deep_dup(&Value::Null), Value::Null);
        assert_eq!(deep_dup(&json!(true)), json!(true));
        assert_eq!(deep_dup(&json!(false)), json!(false));
    }
}
