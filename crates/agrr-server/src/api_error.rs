//! HTTP failure JSON helpers for the API edge (4xx/5xx).
//!
//! Contract: `errors` is a non-empty `string[]`. During migration, legacy `error` (and
//! `message` for `{success:false}` bodies) are duplicated alongside `errors`.

use serde_json::{json, Map, Value};

/// Single-message failure with legacy `error` key for transitional clients.
pub fn single_failure(message: &str) -> Value {
    json!({
        "errors": [message],
        "error": message,
    })
}

/// Like [`single_failure`] with an `error_code`.
pub fn single_failure_with_code(message: &str, error_code: &str) -> Value {
    let mut body = single_failure(message);
    if let Some(obj) = body.as_object_mut() {
        obj.insert("error_code".into(), json!(error_code));
    }
    body
}

/// Merges `extra` object fields into a failure body (e.g. weather metadata).
pub fn extend_failure(base: Value, extra: Value) -> Value {
    let mut merged = match base {
        Value::Object(map) => map,
        _ => Map::new(),
    };
    if let Value::Object(extra_map) = extra {
        for (k, v) in extra_map {
            merged.insert(k, v);
        }
    }
    Value::Object(merged)
}

/// `{success:false}` style body with `errors` + legacy `error` / `message`.
pub fn success_false(message: &str) -> Value {
    json!({
        "success": false,
        "errors": [message],
        "error": message,
        "message": message,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn single_failure_includes_non_empty_errors_array() {
        let body = single_failure("rate_limit");
        let errors = body["errors"].as_array().expect("errors array");
        assert_eq!(1, errors.len());
        assert_eq!("rate_limit", errors[0].as_str().unwrap());
        assert_eq!("rate_limit", body["error"].as_str().unwrap());
    }

    #[test]
    fn single_failure_with_code_preserves_error_code() {
        let body = single_failure_with_code("missing", "missing_blueprints");
        assert_eq!("missing", body["errors"][0].as_str().unwrap());
        assert_eq!("missing_blueprints", body["error_code"].as_str().unwrap());
    }

    #[test]
    fn extend_failure_merges_extra_fields() {
        let base = single_failure("weather_data_not_ready");
        let body = extend_failure(
            base,
            json!({
                "weather_data_status": "fetching",
                "weather_data_progress": 42
            }),
        );
        assert_eq!("weather_data_not_ready", body["errors"][0].as_str().unwrap());
        assert_eq!("fetching", body["weather_data_status"].as_str().unwrap());
        assert_eq!(42, body["weather_data_progress"].as_i64().unwrap());
    }
}
