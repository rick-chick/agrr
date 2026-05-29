//! Ruby: `Domain::Fertilize::Mappers::FertilizeAiAgrrMapper`

use std::collections::BTreeMap;

use serde_json::{Map, Value};

/// Normalize agrr fertilize JSON into persistence attributes.
pub fn normalize_fertilize_payload(info: &Value) -> Option<BTreeMap<String, Value>> {
    let mut data = info.get("fertilize").cloned();
    if let Some(ref inner) = data {
        if let Ok(serialized) = serde_json::to_value(inner) {
            if let Ok(cloned) = serde_json::from_value(serialized) {
                data = Some(cloned);
            }
        }
    }

    let mut data = if let Some(d) = data {
        value_to_map(d)?
    } else {
        let direct_keys = ["name", "description", "package_size", "n", "p", "k", "npk"];
        let mut map = BTreeMap::new();
        for key in direct_keys {
            if let Some(v) = info.get(key) {
                if !v.is_null() {
                    map.insert(key.to_string(), v.clone());
                }
            }
        }
        if map.is_empty() {
            return None;
        }
        if map.get("n").is_none() {
            if let Some(npk_raw) = map.remove("npk") {
                let npk_str = npk_raw.as_str().unwrap_or("").trim();
                if !npk_str.is_empty() {
                    map.extend(parse_npk_string(npk_str));
                }
            }
        } else {
            map.remove("npk");
        }
        map
    };

    if let Some(v) = data.remove("package_size") {
        data.insert(
            "package_size".into(),
            parse_package_size(&v).map_or(Value::Null, |n| Value::from(n)),
        );
    }
    for key in ["n", "p", "k"] {
        if let Some(v) = data.get(key).cloned() {
            data.insert(
                key.to_string(),
                normalize_nutrient_value(&v).map_or(Value::Null, |n| Value::from(n)),
            );
        }
    }

    Some(data)
}

fn value_to_map(value: Value) -> Option<BTreeMap<String, Value>> {
    match value {
        Value::Object(map) => Some(map.into_iter().collect()),
        _ => None,
    }
}

pub fn parse_package_size(value: &Value) -> Option<f64> {
    let s = match value {
        Value::Null => return None,
        Value::Number(n) => return n.as_f64(),
        Value::String(s) => s.as_str(),
        _ => return None,
    };
    if s.trim().is_empty() {
        return None;
    }
    let numeric: String = s.chars().filter(|c| c.is_ascii_digit() || *c == '.').collect();
    if numeric.is_empty() {
        return None;
    }
    let parsed = numeric.parse::<f64>().ok()?;
    if parsed == 0.0 && !s.chars().any(|c| c.is_ascii_digit()) {
        None
    } else {
        Some(parsed)
    }
}

pub fn parse_npk_string(value: &str) -> BTreeMap<String, Value> {
    let mut out = BTreeMap::new();
    if value.trim().is_empty() {
        return out;
    }
    let numbers: Vec<&str> = value
        .split(['-', '/', '\\'])
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    let n_value = numbers.first().and_then(|s| s.parse::<f64>().ok());
    let p_value = numbers.get(1).and_then(|s| s.parse::<f64>().ok());
    let k_value = numbers.get(2).and_then(|s| s.parse::<f64>().ok());
    if let Some(n) = normalize_nutrient_value(&Value::from(n_value.unwrap_or(0.0))) {
        out.insert("n".into(), Value::from(n));
    }
    if let Some(p) = normalize_nutrient_value(&Value::from(p_value.unwrap_or(0.0))) {
        out.insert("p".into(), Value::from(p));
    }
    if let Some(k) = normalize_nutrient_value(&Value::from(k_value.unwrap_or(0.0))) {
        out.insert("k".into(), Value::from(k));
    }
    out
}

pub fn normalize_nutrient_value(value: &Value) -> Option<f64> {
    let numeric = match value {
        Value::Null => return None,
        Value::Number(n) => n.as_f64()?,
        Value::String(s) => s.parse().ok()?,
        _ => return None,
    };
    if numeric == 0.0 {
        None
    } else {
        Some(numeric)
    }
}

#[cfg(test)]
mod mappers_fertilize_ai_agrr_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/fertilize/mappers_fertilize_ai_agrr_mapper_test.rs"));
}
