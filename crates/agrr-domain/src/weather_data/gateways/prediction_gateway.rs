//! Ruby: `Domain::WeatherData::Gateways::PredictionGateway`

use serde_json::Value;

/// Ruby: `Domain::WeatherData::Gateways::PredictionGateway`
pub trait PredictionGateway: Send + Sync {
    fn predict(
        &self,
        historical_data: &Value,
        days: i64,
        model: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
