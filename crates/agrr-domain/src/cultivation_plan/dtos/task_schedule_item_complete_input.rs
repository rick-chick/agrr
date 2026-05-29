//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInput`

use std::collections::BTreeMap;

use serde_json::Value;
use time::{Date, OffsetDateTime};

use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::ClockPort;
use crate::shared::validation::ValidationErrors;

/// Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskScheduleItemCompleteInput {
    pub actual_date: Date,
    pub actual_notes: Option<String>,
    pub completed_at: OffsetDateTime,
}

impl TaskScheduleItemCompleteInput {
    pub fn new(
        actual_date: Date,
        actual_notes: Option<String>,
        completed_at: OffsetDateTime,
    ) -> Self {
        Self {
            actual_date,
            actual_notes,
            completed_at,
        }
    }

    pub fn from_completion_params(
        completion_params: &BTreeMap<String, Value>,
        clock: &dyn ClockPort,
    ) -> Result<Self, RecordInvalidError> {
        let actual_date =
            Self::coerce_actual_date(hash_get(completion_params, "actual_date"), clock)?;
        let notes = hash_get(completion_params, "notes")
            .and_then(|v| v.as_str())
            .map(str::to_string);
        Ok(Self::new(actual_date, notes, clock.now()))
    }

    fn coerce_actual_date(
        raw: Option<&Value>,
        clock: &dyn ClockPort,
    ) -> Result<Date, RecordInvalidError> {
        match raw {
            None | Some(Value::Null) => Ok(clock.today()),
            Some(Value::String(s)) if s.trim().is_empty() => Ok(clock.today()),
            Some(Value::String(s)) => parse_date_string(s).map_err(|msg| record_invalid_date(&msg)),
            Some(Value::Number(_)) => Err(record_invalid_date("invalid date")),
            Some(_) => Err(record_invalid_date("invalid date")),
        }
    }
}

fn hash_get<'a>(h: &'a BTreeMap<String, Value>, key: &str) -> Option<&'a Value> {
    h.get(key)
}

fn parse_date_string(s: &str) -> Result<Date, String> {
    crate::cultivation_plan::helpers::parse_iso_date(s)
        .ok_or_else(|| format!("invalid date {s}"))
}

fn record_invalid_date(message: &str) -> RecordInvalidError {
    let mut errors = ValidationErrors::new();
    errors.add("actual_date", message);
    RecordInvalidError::new(Some(message.to_string()), Some(errors))
}

#[cfg(test)]
mod dtos_task_schedule_item_complete_input_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/dtos_task_schedule_item_complete_input_test.rs"));
}
