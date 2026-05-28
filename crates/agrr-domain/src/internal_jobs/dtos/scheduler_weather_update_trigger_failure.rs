/// Ruby: `Domain::InternalJobs::Dtos::SchedulerWeatherUpdateTriggerFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchedulerWeatherUpdateTriggerFailure {
    pub message: String,
}

impl SchedulerWeatherUpdateTriggerFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}
