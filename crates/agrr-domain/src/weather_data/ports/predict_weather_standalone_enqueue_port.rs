//! Ruby: `Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult`

/// Ruby: `Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PredictWeatherStandaloneEnqueueResult {
    pub ok: bool,
    pub error_message: Option<String>,
}

impl PredictWeatherStandaloneEnqueueResult {
    pub fn success() -> Self {
        Self {
            ok: true,
            error_message: None,
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            ok: false,
            error_message: Some(message.into()),
        }
    }
}

/// Ruby: `Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueuePort`
pub trait PredictWeatherStandaloneEnqueuePort: Send + Sync {
    fn enqueue_predict_weather_standalone(
        &self,
        farm_id: i64,
        days: Option<i32>,
        model: &str,
        target_end_date: Option<time::Date>,
        cultivation_plan_id: Option<i64>,
        channel_class: Option<&str>,
    ) -> PredictWeatherStandaloneEnqueueResult;
}
