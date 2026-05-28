//! Ruby: `Domain::CultivationPlan::Errors::EffectivePlanningPeriodInvalidDateError`

use std::fmt;

use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EffectivePlanningPeriodDateField {
    StartDate,
    CompletionDate,
    ToStartDate,
}

impl EffectivePlanningPeriodDateField {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::StartDate => "start_date",
            Self::CompletionDate => "completion_date",
            Self::ToStartDate => "to_start_date",
        }
    }
}

impl fmt::Display for EffectivePlanningPeriodDateField {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("Invalid {field} date: {raw_value:?}")]
pub struct EffectivePlanningPeriodInvalidDateError {
    pub raw_value: String,
    pub field: EffectivePlanningPeriodDateField,
    pub allocation_id: Option<i64>,
    pub move_payload: Option<String>,
}

impl EffectivePlanningPeriodInvalidDateError {
    pub fn new(
        raw_value: impl Into<String>,
        field: EffectivePlanningPeriodDateField,
        allocation_id: Option<i64>,
        move_payload: Option<String>,
    ) -> Self {
        Self {
            raw_value: raw_value.into(),
            field,
            allocation_id,
            move_payload,
        }
    }
}
