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
mod dtos_predicted_weather_snapshot_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/dtos_predicted_weather_snapshot_test.rs"));
}
