//! GCS payload store for predicted weather (`predicted_weather/{scope}/{id}.json`).

use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use serde_json::Value;

use crate::gcs_object_client::GcsObjectClient;
use crate::weather_json::{WeatherDataGcsConfig, WeatherDataGcsError};

const PREFIX: &str = "predicted_weather";

pub struct PredictedWeatherGcsStoreGateway {
    client: GcsObjectClient,
}

impl PredictedWeatherGcsStoreGateway {
    pub fn new(config: WeatherDataGcsConfig) -> Self {
        Self {
            client: GcsObjectClient::new(config),
        }
    }

    pub fn from_env() -> Result<Self, WeatherDataGcsError> {
        Ok(Self::new(WeatherDataGcsConfig::from_env_for_predictions()?))
    }

    pub fn object_key(scope: PredictedWeatherScope, scope_id: i64) -> String {
        format!("{PREFIX}/{}/{}.json", scope.as_str(), scope_id)
    }
}

impl PredictedWeatherStoreGateway for PredictedWeatherGcsStoreGateway {
    fn read_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
        let key = Self::object_key(scope, scope_id);
        let bytes = self
            .client
            .read_object(&key)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
        let Some(bytes) = bytes else {
            return Ok(None);
        };
        let value: Value = serde_json::from_slice(&bytes)?;
        Ok(Some(value))
    }

    fn write_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
        payload: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let key = Self::object_key(scope, scope_id);
        let bytes = serde_json::to_vec(payload)?;
        self.client
            .write_object(&key, &bytes)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }

    fn copy_plan_payload(
        &self,
        from_plan_id: i64,
        to_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let from_key = Self::object_key(PredictedWeatherScope::Plan, from_plan_id);
        let bytes = self
            .client
            .read_object(&from_key)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
        let Some(bytes) = bytes else {
            return Ok(());
        };
        let to_key = Self::object_key(PredictedWeatherScope::Plan, to_plan_id);
        self.client
            .write_object(&to_key, &bytes)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::weather_data::dtos::PredictedWeatherScope;

    #[test]
    fn object_key_uses_scope_and_id() {
        assert_eq!(
            PredictedWeatherGcsStoreGateway::object_key(PredictedWeatherScope::Location, 42),
            "predicted_weather/location/42.json"
        );
        assert_eq!(
            PredictedWeatherGcsStoreGateway::object_key(PredictedWeatherScope::Plan, 7),
            "predicted_weather/plan/7.json"
        );
    }
}
