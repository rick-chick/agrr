//! Ruby: `Domain::CultivationPlan::Errors::EntryScheduleOptimizationError`

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub struct EntryScheduleOptimizationError {
    pub error_key: String,
    pub message: String,
}

impl EntryScheduleOptimizationError {
    pub fn new(error_key: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            error_key: error_key.into(),
            message: message.into(),
        }
    }
}

impl fmt::Display for EntryScheduleOptimizationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for EntryScheduleOptimizationError {}
