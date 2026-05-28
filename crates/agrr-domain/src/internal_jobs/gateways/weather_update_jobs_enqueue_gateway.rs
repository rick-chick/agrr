/// Ruby: `WeatherUpdateJobsEnqueueGateway::EnqueueWeatherUpdateJobsResult`
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EnqueueWeatherUpdateJobsResult {
    Success,
    Failure { error_message: String },
}

impl EnqueueWeatherUpdateJobsResult {
    pub fn success() -> Self {
        Self::Success
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self::Failure {
            error_message: message.into(),
        }
    }
}

/// Ruby: `Domain::InternalJobs::Gateways::WeatherUpdateJobsEnqueueGateway`
pub trait WeatherUpdateJobsEnqueueGateway: Send + Sync {
    fn enqueue_weather_update_jobs(&self) -> EnqueueWeatherUpdateJobsResult;
}
