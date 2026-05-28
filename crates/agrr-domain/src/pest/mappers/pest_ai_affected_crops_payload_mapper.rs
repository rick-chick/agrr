use serde_json::Value;

/// Ruby: `Domain::Pest::Mappers::PestAiAffectedCropsPayloadMapper`
pub fn extract_crop_ids(affected_crops: &[Value]) -> Vec<i64> {
    let mut ids = Vec::new();
    for entry in affected_crops {
        if let Some(id) = crop_id_from_entry(entry) {
            if id > 0 {
                ids.push(id);
            }
        }
    }
    ids.sort_unstable();
    ids.dedup();
    ids
}

pub fn extract_crop_names(affected_crops: &[Value]) -> Vec<String> {
    let mut names = Vec::new();
    for entry in affected_crops {
        if let Some(name) = crop_name_from_entry(entry) {
            let trimmed = name.trim();
            if !trimmed.is_empty() {
                names.push(trimmed.to_string());
            }
        }
    }
    names.sort_unstable();
    names.dedup();
    names
}

fn crop_id_from_entry(entry: &Value) -> Option<i64> {
    match entry {
        Value::Object(map) => map
            .get("crop_id")
            .or_else(|| map.get("cropId"))
            .and_then(Value::as_i64),
        _ => None,
    }
}

fn crop_name_from_entry(entry: &Value) -> Option<String> {
    match entry {
        Value::Object(map) => map
            .get("crop_name")
            .or_else(|| map.get("cropName"))
            .and_then(|v| v.as_str().map(str::to_string)),
        _ => None,
    }
}
