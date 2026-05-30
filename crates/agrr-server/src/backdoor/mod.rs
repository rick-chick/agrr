//! Backdoor API helpers (Ruby `Api::V1::Backdoor::BackdoorController` parity).

pub mod daemon_status;
pub mod routes;

pub use daemon_status::build_backdoor_status_json;
