use serde_json::Value;

use crate::field_cultivation::dtos::CultivationPlanWeatherInput;

pub trait FieldCultivationWeatherPredictionServiceGateway: Send + Sync {
    fn predict_for_cultivation_plan(
        &self,
        weather_location: &Value,
        farm: &Value,
        plan_weather: &CultivationPlanWeatherInput,
    ) -> Option<Value>;
}

pub trait FieldCultivationPredictionGateway: Send + Sync {
    fn predict(
        &self,
        historical_data: &Value,
        days: i64,
        model: &str,
    ) -> Option<Value>;
}
