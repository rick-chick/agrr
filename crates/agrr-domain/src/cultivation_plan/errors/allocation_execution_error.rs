//! Ruby: `Domain::CultivationPlan::Errors::AllocationExecutionError`

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub struct AllocationExecutionError {
    pub message: String,
}

impl AllocationExecutionError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for AllocationExecutionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for AllocationExecutionError {}
