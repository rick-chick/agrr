//! Ruby: `Domain::CultivationPlan::Errors::CultivationPlanCropMissingError`

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanCropMissingError {
    pub message: String,
}

impl CultivationPlanCropMissingError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for CultivationPlanCropMissingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for CultivationPlanCropMissingError {}
