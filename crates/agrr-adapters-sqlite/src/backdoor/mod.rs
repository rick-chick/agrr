//! Backdoor diagnostics and dangerous DB clear (Ruby `app/adapters/backdoor/gateways/*`).

pub mod application_database_clear_gateway;
pub mod backdoor_diagnostics_gateway;
pub mod shell_stdout_capture;

pub use application_database_clear_gateway::ApplicationDatabaseClearSqliteGateway;
pub use backdoor_diagnostics_gateway::{
    BackdoorCreateUserAttrs, BackdoorCreateUserResult, BackdoorDbStatsCounts,
    BackdoorDiagnosticsSqliteGateway, BackdoorUpdateUserAttrs, BackdoorUpdateUserResult,
    BackdoorUserDetail, BackdoorUserSummary, BackdoorUsersListPayload,
};
pub use shell_stdout_capture::ShellStdoutCaptureCliGateway;
