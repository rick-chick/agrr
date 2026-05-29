use crate::internal_jobs::dtos::SchedulerWeatherUpdateTriggerFailure;
use crate::internal_jobs::gateways::{
    EnqueueWeatherUpdateJobsResult, WeatherUpdateJobsEnqueueGateway,
};
use crate::internal_jobs::ports::SchedulerWeatherUpdateTriggerOutputPort;

/// Ruby: `Domain::InternalJobs::Interactors::SchedulerWeatherUpdateJobsTriggerInteractor`
pub struct SchedulerWeatherUpdateJobsTriggerInteractor<'a> {
    output_port: &'a mut dyn SchedulerWeatherUpdateTriggerOutputPort,
    gateway: &'a dyn WeatherUpdateJobsEnqueueGateway,
}

impl<'a> SchedulerWeatherUpdateJobsTriggerInteractor<'a> {
    pub fn new(
        output_port: &'a mut dyn SchedulerWeatherUpdateTriggerOutputPort,
        gateway: &'a dyn WeatherUpdateJobsEnqueueGateway,
    ) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self) {
        let result = self.gateway.enqueue_weather_update_jobs();
        match result {
            EnqueueWeatherUpdateJobsResult::Success => self.output_port.on_success(),
            EnqueueWeatherUpdateJobsResult::Failure { error_message } => self
                .output_port
                .on_failure(SchedulerWeatherUpdateTriggerFailure::new(error_message)),
        }
    }
}

#[cfg(test)]
mod interactors_scheduler_weather_update_jobs_trigger_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/internal_jobs/interactors_scheduler_weather_update_jobs_trigger_interactor_test.rs"));
}
