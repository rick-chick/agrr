/// Ruby: `Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReferenceFlagChangeDeniedFailure {
    pub message: String,
    pub resource_id: i64,
}

impl ReferenceFlagChangeDeniedFailure {
    pub fn new(message: impl Into<String>, resource_id: i64) -> Self {
        Self {
            message: message.into(),
            resource_id,
        }
    }
}

#[cfg(test)]
mod dtos_reference_flag_change_denied_failure_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/dtos_reference_flag_change_denied_failure_test.rs"));
}
