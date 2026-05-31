//! Normalize agrr `progress` daemon JSON for domain mappers (Rails `ProgressDaemonGateway` parity).
//!
//! agrr stdout uses `daily_progress`; `FieldCultivationClimateDataMapper` reads `progress_records`.

use serde_json::{json, Value};

pub fn empty_progress_result() -> Value {
    json!({ "progress_records": [] })
}

/// Map agrr progress payload to `{ "progress_records": [...] }` shape expected by domain mappers.
pub fn normalize_progress_result(payload: &Value) -> Value {
    if let Some(records) = payload.get("progress_records").and_then(|v| v.as_array()) {
        if !records.is_empty() {
            return payload.clone();
        }
    }

    if let Some(daily) = payload.get("daily_progress").and_then(|v| v.as_array()) {
        if daily.is_empty() {
            return empty_progress_result();
        }
        let progress_records: Vec<Value> = daily.iter().map(map_daily_progress_entry).collect();
        let mut out = payload.clone();
        if let Some(obj) = out.as_object_mut() {
            obj.insert("progress_records".into(), Value::Array(progress_records));
        } else {
            out = json!({ "progress_records": progress_records });
        }
        return out;
    }

    empty_progress_result()
}

fn map_daily_progress_entry(item: &Value) -> Value {
    let date = item
        .get("date")
        .or_else(|| item.get("time"))
        .cloned()
        .unwrap_or(Value::Null);
    let cumulative_gdd = item
        .get("cumulative_gdd")
        .or_else(|| item.get("gdd_accumulated"))
        .or_else(|| item.get("total_gdd"))
        .cloned()
        .unwrap_or(Value::Null);
    let stage_name = item
        .get("stage_name")
        .or_else(|| item.get("stage"))
        .cloned();
    let mut record = json!({
        "date": date,
        "cumulative_gdd": cumulative_gdd,
    });
    if let Some(name) = stage_name {
        if let Some(obj) = record.as_object_mut() {
            obj.insert("stage_name".into(), name);
        }
    }
    record
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_nonempty_progress_records() {
        let payload = json!({
            "progress_records": [{ "date": "2026-01-01", "cumulative_gdd": 10.0, "stage_name": "S1" }]
        });
        let out = normalize_progress_result(&payload);
        assert_eq!(out["progress_records"].as_array().unwrap().len(), 1);
    }

    #[test]
    fn maps_daily_progress_to_progress_records() {
        let payload = json!({
            "daily_progress": [
                { "date": "2026-01-01", "cumulative_gdd": 5.0, "stage_name": "育苗" }
            ]
        });
        let out = normalize_progress_result(&payload);
        let records = out["progress_records"].as_array().unwrap();
        assert_eq!(records.len(), 1);
        assert_eq!(records[0]["stage_name"], "育苗");
    }

    #[test]
    fn empty_daily_progress_yields_empty_progress_records() {
        let payload = json!({ "daily_progress": [] });
        let out = normalize_progress_result(&payload);
        assert!(out["progress_records"].as_array().unwrap().is_empty());
    }
}
