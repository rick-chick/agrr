use crate::backdoor::dtos::{BackdoorClearDatabaseFailure, BackdoorClearDatabaseOutput};

/// Ruby: `Domain::Backdoor::Ports::BackdoorClearDatabaseOutputPort`
pub trait BackdoorClearDatabaseOutputPort {
    fn on_success(&mut self, success_dto: BackdoorClearDatabaseOutput);
    fn on_failure(&mut self, failure_dto: BackdoorClearDatabaseFailure);
}
