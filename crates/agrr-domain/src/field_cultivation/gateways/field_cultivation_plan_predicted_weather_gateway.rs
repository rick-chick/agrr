use serde_json::Value;

/// Minimal plan write port (avoids `cultivation_plan` module).
pub trait FieldCultivationPlanPredictedWeatherGateway: Send + Sync {
    fn update_predicted_weather_data(
        &self,
        plan_id: i64,
        weather_payload: Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
