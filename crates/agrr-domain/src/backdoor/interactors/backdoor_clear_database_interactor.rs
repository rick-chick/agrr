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
mod interactors_backdoor_clear_database_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/backdoor/interactors_backdoor_clear_database_interactor_test.rs"));
}
