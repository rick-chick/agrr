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
mod tests {
    use super::*;

    struct FakeGateway {
        result: EnqueueWeatherUpdateJobsResult,
    }

    impl WeatherUpdateJobsEnqueueGateway for FakeGateway {
        fn enqueue_weather_update_jobs(&self) -> EnqueueWeatherUpdateJobsResult {
            self.result.clone()
        }
    }

    #[derive(Default)]
    struct RecordingPort {
        success: usize,
        failure: usize,
        last_failure_message: Option<String>,
    }

    impl SchedulerWeatherUpdateTriggerOutputPort for RecordingPort {
        fn on_success(&mut self) {
            self.success += 1;
        }
        fn on_failure(&mut self, failure_dto: SchedulerWeatherUpdateTriggerFailure) {
            self.failure += 1;
            self.last_failure_message = Some(failure_dto.message);
        }
    }

    // Ruby: test "success calls on_success"
    #[test]
    fn success_calls_on_success() {
        let gateway = FakeGateway {
            result: EnqueueWeatherUpdateJobsResult::success(),
        };
        let mut port = RecordingPort::default();
        let mut interactor = SchedulerWeatherUpdateJobsTriggerInteractor::new(&mut port, &gateway);

        interactor.call();

        assert_eq!(port.success, 1);
        assert_eq!(port.failure, 0);
    }

    // Ruby: test "failure maps message to failure dto"
    #[test]
    fn failure_maps_message_to_failure_dto() {
        let gateway = FakeGateway {
            result: EnqueueWeatherUpdateJobsResult::failure("enqueue failed"),
        };
        let mut port = RecordingPort::default();
        let mut interactor = SchedulerWeatherUpdateJobsTriggerInteractor::new(&mut port, &gateway);

        interactor.call();

        assert_eq!(port.failure, 1);
        assert_eq!(
            port.last_failure_message.as_deref(),
            Some("enqueue failed")
        );
    }
}
