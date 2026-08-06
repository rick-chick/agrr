use crate::user_account::dtos::{UserDataExport, UserDataExportFailure};

/// Ruby: `Domain::UserAccount::Ports::UserDataExportOutputPort`
pub trait UserDataExportOutputPort {
    fn on_success(&mut self, export: UserDataExport);
    fn on_failure(&mut self, failure: UserDataExportFailure);
}
