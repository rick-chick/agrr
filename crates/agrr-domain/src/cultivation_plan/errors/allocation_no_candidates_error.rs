//! Ruby: `Domain::CultivationPlan::Errors::AllocationNoCandidatesError`

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub struct AllocationNoCandidatesError {
    pub message: String,
}

impl AllocationNoCandidatesError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for AllocationNoCandidatesError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for AllocationNoCandidatesError {}
