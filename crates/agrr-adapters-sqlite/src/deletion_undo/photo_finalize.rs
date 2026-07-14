//! Deferred work record photo object cleanup when deletion undo expires.

use super::DeletionUndoSqliteGateway;
use agrr_domain::work_record::gateways::WorkRecordPhotoObjectStoreGateway;
use serde_json::Value;

pub fn deferred_photo_storage_keys_from_snapshot(snapshot: &Value) -> Vec<String> {
    let mut keys = Vec::new();
    collect_photo_keys_from_node(snapshot, &mut keys);
    keys.sort();
    keys.dedup();
    keys
}

fn collect_photo_keys_from_node(node: &Value, keys: &mut Vec<String>) {
    let model = node.get("model").and_then(|v| v.as_str()).unwrap_or("");
    if model == "WorkRecordPhoto" {
        if let Some(status) = node
            .pointer("/attributes/status")
            .and_then(|v| v.as_str())
        {
            if status == "ready" {
                if let Some(key) = node
                    .pointer("/attributes/storage_key")
                    .and_then(|v| v.as_str())
                {
                    keys.push(key.to_string());
                }
            }
        }
    }

    if let Some(associations) = node.get("associations").and_then(|v| v.as_object()) {
        for child in associations.values() {
            match child {
                Value::Array(items) => {
                    for item in items {
                        collect_photo_keys_from_node(item, keys);
                    }
                }
                Value::Object(_) => collect_photo_keys_from_node(child, keys),
                _ => {}
            }
        }
    }
}

pub fn deferred_photo_storage_keys_from_metadata(metadata: &Value) -> Vec<String> {
    metadata
        .get("deferred_photo_storage_keys")
        .and_then(|v| v.as_array())
        .map(|items| {
            items
                .iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default()
}

impl DeletionUndoSqliteGateway {
    pub fn deferred_photo_storage_keys(
        &self,
        event_id: &str,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool().with_read_box(|conn| {
            let (snapshot_json, metadata_json): (String, String) = conn.query_row(
                "SELECT snapshot, metadata FROM deletion_undo_events WHERE id = ?1",
                rusqlite::params![event_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )?;
            let metadata: Value = serde_json::from_str(&metadata_json)
                .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;
            let mut keys = deferred_photo_storage_keys_from_metadata(&metadata);
            if keys.is_empty() {
                let snapshot: Value = serde_json::from_str(&snapshot_json)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;
                keys = deferred_photo_storage_keys_from_snapshot(&snapshot);
            }
            Ok(keys)
        })
    }

}

pub fn finalize_deferred_photo_objects<S: WorkRecordPhotoObjectStoreGateway + ?Sized>(
    gateway: &DeletionUndoSqliteGateway,
    event_id: &str,
    object_store: &S,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let keys = gateway.deferred_photo_storage_keys(event_id)?;
    for key in keys {
        let _ = object_store.delete_object(&key);
    }
    Ok(())
}

#[cfg(test)]
mod photo_finalize_unit_test {
    use super::*;
    use serde_json::json;

    #[test]
    fn collects_ready_photo_storage_keys_from_nested_snapshot() {
        let snapshot = json!({
            "model": "WorkRecord",
            "attributes": { "id": 1 },
            "associations": {
                "work_record_photos": [{
                    "model": "WorkRecordPhoto",
                    "attributes": {
                        "status": "ready",
                        "storage_key": "work_record_photos/1/2/a.jpg"
                    },
                    "associations": {}
                }, {
                    "model": "WorkRecordPhoto",
                    "attributes": {
                        "status": "pending",
                        "storage_key": "work_record_photos/1/2/b.jpg"
                    },
                    "associations": {}
                }]
            }
        });

        let keys = deferred_photo_storage_keys_from_snapshot(&snapshot);
        assert_eq!(keys, vec!["work_record_photos/1/2/a.jpg".to_string()]);
    }
}
