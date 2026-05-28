use thiserror::Error;

/// Ruby: `Domain::Shared::Policies::PolicyPermissionDenied`
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("policy permission denied")]
pub struct PolicyPermissionDenied;
