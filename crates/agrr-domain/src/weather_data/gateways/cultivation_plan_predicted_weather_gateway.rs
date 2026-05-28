//! Cultivation plan gateway slice for weather prediction.

use serde_json::Value;

/// Ruby: cultivation plan gateway for predicted weather persistence.
pub trait CultivationPlanPredictedWeatherGateway: Send + Sync {
    fn update_predicted_weather_data(
        &self,
        plan_id: i64,
        payload: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
