use crate::internal_jobs::dtos::SchedulerWeatherUpdateTriggerFailure;

/// Ruby: `Domain::InternalJobs::Ports::SchedulerWeatherUpdateTriggerOutputPort`
pub trait SchedulerWeatherUpdateTriggerOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure_dto: SchedulerWeatherUpdateTriggerFailure);
}
