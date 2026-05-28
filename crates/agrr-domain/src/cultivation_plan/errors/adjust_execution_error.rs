//! Ruby: `Domain::CultivationPlan::Errors::AdjustExecutionError`

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub struct AdjustExecutionError {
    pub message: String,
}

impl AdjustExecutionError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for AdjustExecutionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for AdjustExecutionError {}
