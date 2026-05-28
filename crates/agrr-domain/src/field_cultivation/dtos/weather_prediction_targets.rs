use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherPredictionTargets {
    pub weather_location: Value,
    pub farm: Value,
}
