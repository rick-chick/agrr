use crate::backdoor::dtos::{BackdoorClearDatabaseFailure, BackdoorClearDatabaseOutput};
use crate::backdoor::gateways::{ApplicationDatabaseClearGateway, ClearApplicationDataResult};
use crate::backdoor::ports::BackdoorClearDatabaseOutputPort;
use crate::shared::ports::LoggerPort;

/// Ruby: `Domain::Backdoor::Interactors::BackdoorClearDatabaseInteractor`
pub struct BackdoorClearDatabaseInteractor<'a> {
    output_port: &'a mut dyn BackdoorClearDatabaseOutputPort,
    gateway: &'a dyn ApplicationDatabaseClearGateway,
    logger: &'a dyn LoggerPort,
}

impl<'a> BackdoorClearDatabaseInteractor<'a> {
    pub fn new(
        output_port: &'a mut dyn BackdoorClearDatabaseOutputPort,
        gateway: &'a dyn ApplicationDatabaseClearGateway,
        logger: &'a dyn LoggerPort,
    ) -> Self {
        Self {
            output_port,
            gateway,
            logger,
        }
    }

    pub fn call(&mut self) {
        let result = self
            .gateway
            .clear_application_data_preserving_anonymous_users();
        match result {
            ClearApplicationDataResult::Success {
                before_stats,
                after_stats,
            } => {
                let msg = format!(
                    "✅ Database cleared successfully. Before: {:?}, After: {:?}",
                    before_stats, after_stats
                );
                self.logger.error(&msg);
                self.output_port.on_success(BackdoorClearDatabaseOutput::new(
                    before_stats,
                    after_stats,
                ));
            }
            ClearApplicationDataResult::Failure { error_message } => self
                .output_port
                .on_failure(BackdoorClearDatabaseFailure::new(error_message)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::backdoor::gateways::ApplicationDataStats;
    use std::sync::Mutex;

    struct FakeGateway {
        result: ClearApplicationDataResult,
    }

    impl ApplicationDatabaseClearGateway for FakeGateway {
        fn clear_application_data_preserving_anonymous_users(&self) -> ClearApplicationDataResult {
            self.result.clone()
        }
    }

    struct FakeLogger {
        error_messages: Mutex<Vec<String>>,
    }

    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, message: &str) {
            self.error_messages.lock().unwrap().push(message.to_string());
        }
        fn debug(&self, _: &str) {}
    }

    #[derive(Default)]
    struct RecordingPort {
        success_count: usize,
        failure_count: usize,
        last_success: Option<BackdoorClearDatabaseOutput>,
        last_failure: Option<BackdoorClearDatabaseFailure>,
    }

    impl BackdoorClearDatabaseOutputPort for RecordingPort {
        fn on_success(&mut self, success_dto: BackdoorClearDatabaseOutput) {
            self.success_count += 1;
            self.last_success = Some(success_dto);
        }
        fn on_failure(&mut self, failure_dto: BackdoorClearDatabaseFailure) {
            self.failure_count += 1;
            self.last_failure = Some(failure_dto);
        }
    }

    // Ruby: test "success maps stats to success dto and logs summary"
    #[test]
    fn success_maps_stats_and_logs_summary() {
        let before_s = ApplicationDataStats {
            users: 1,
            farms: 2,
            fields: 3,
            crops: 4,
            cultivation_plans: 5,
        };
        let after_s = ApplicationDataStats {
            users: 0,
            farms: 0,
            fields: 0,
            crops: 0,
            cultivation_plans: 0,
        };
        let gateway = FakeGateway {
            result: ClearApplicationDataResult::success(before_s, after_s),
        };
        let logger = FakeLogger {
            error_messages: Mutex::new(vec![]),
        };
        let mut port = RecordingPort::default();
        let mut interactor = BackdoorClearDatabaseInteractor::new(&mut port, &gateway, &logger);

        interactor.call();

        assert_eq!(port.success_count, 1);
        let success = port.last_success.as_ref().unwrap();
        assert_eq!(success.before_stats, before_s);
        assert_eq!(success.after_stats, after_s);
        let logs = logger.error_messages.lock().unwrap();
        assert_eq!(logs.len(), 1);
        assert!(logs[0].contains("Database cleared successfully"));
        assert!(logs[0].contains("users: 1"));
        assert!(logs[0].contains("users: 0"));
    }

    // Ruby: test "failure maps error message to failure dto"
    #[test]
    fn failure_maps_error_message() {
        let gateway = FakeGateway {
            result: ClearApplicationDataResult::failure("Failed to clear database: boom"),
        };
        let logger = FakeLogger {
            error_messages: Mutex::new(vec![]),
        };
        let mut port = RecordingPort::default();
        let mut interactor = BackdoorClearDatabaseInteractor::new(&mut port, &gateway, &logger);

        interactor.call();

        assert_eq!(port.failure_count, 1);
        assert_eq!(
            port.last_failure.as_ref().unwrap().message,
            "Failed to clear database: boom"
        );
        assert!(logger.error_messages.lock().unwrap().is_empty());
    }
}
