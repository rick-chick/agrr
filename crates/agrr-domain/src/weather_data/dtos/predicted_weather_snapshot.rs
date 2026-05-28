//! Ruby: `Domain::WeatherData::Dtos::PredictedWeatherSnapshot`

use serde_json::Value;

use crate::weather_data::helpers::copy_and_deep_freeze;

/// Ruby: `Domain::WeatherData::Dtos::PredictedWeatherSnapshot`
#[derive(Debug, Clone)]
pub struct PredictedWeatherSnapshot {
    document: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PredictedWeatherSnapshotError(String);

impl std::fmt::Display for PredictedWeatherSnapshotError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for PredictedWeatherSnapshotError {}

impl PredictedWeatherSnapshot {
    pub fn from_document(doc: Option<Value>) -> Result<Self, PredictedWeatherSnapshotError> {
        Ok(Self {
            document: copy_and_deep_freeze(doc),
        })
    }

    pub fn document(&self) -> Option<&Value> {
        self.document.as_ref()
    }

    pub fn storage_column_value(
        payload: Option<PredictedWeatherSnapshotInput>,
    ) -> Result<Option<Value>, PredictedWeatherSnapshotError> {
        match payload {
            None => Ok(None),
            Some(PredictedWeatherSnapshotInput::Dto(dto)) => Ok(dto.to_storage_hash()),
            Some(PredictedWeatherSnapshotInput::Hash(hash)) => {
                Ok(PredictedWeatherSnapshot::from_document(Some(hash))?.to_storage_hash())
            }
        }
    }

    pub fn to_storage_hash(&self) -> Option<Value> {
        self.document.as_ref().map(deep_dup_json)
    }
}

pub enum PredictedWeatherSnapshotInput {
    Dto(PredictedWeatherSnapshot),
    Hash(Value),
}

fn deep_dup_json(value: &Value) -> Value {
    match value {
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => value.clone(),
        Value::Array(items) => Value::Array(items.iter().map(deep_dup_json).collect()),
        Value::Object(map) => Value::Object(
            map.iter()
                .map(|(k, v)| (k.clone(), deep_dup_json(v)))
                .collect(),
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn from_document_deep_copies_nested_hash() {
        let dto = PredictedWeatherSnapshot::from_document(Some(json!({ "a": { "b": 1 } })))
            .expect("valid");
        let doc = dto.document().expect("document");
        assert_eq!(doc["a"]["b"], 1);
    }

    #[test]
    fn to_storage_hash_returns_mutable_deep_dup() {
        let dto =
            PredictedWeatherSnapshot::from_document(Some(json!({ "x": [ { "y": 2 } ] })))
                .expect("valid");
        let mut h = dto.to_storage_hash().expect("hash");
        h["x"][0]["y"] = json!(99);
        assert_eq!(dto.document().expect("doc")["x"][0]["y"], 2);
    }

    #[test]
    fn storage_column_value_accepts_dto_or_nil() {
        assert!(PredictedWeatherSnapshot::storage_column_value(None)
            .expect("ok")
            .is_none());
        let dto = PredictedWeatherSnapshot::from_document(Some(json!({ "k": "v" })))
            .expect("valid");
        let stored = PredictedWeatherSnapshot::storage_column_value(Some(
            PredictedWeatherSnapshotInput::Dto(dto),
        ))
        .expect("ok");
        assert_eq!(stored, Some(json!({ "k": "v" })));
    }
}
