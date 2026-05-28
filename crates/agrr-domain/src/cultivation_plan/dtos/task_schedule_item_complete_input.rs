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
mod tests {
    use super::*;
    use time::macros::{date, datetime};

    struct FakeClock {
        today_val: Date,
        now_val: OffsetDateTime,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            self.today_val
        }

        fn now(&self) -> OffsetDateTime {
            self.now_val
        }
    }

    // Ruby: test "actual_date が空なら clock.today を使う"
    #[test]
    fn actual_date_defaults_to_clock_today_when_empty() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let dto =
            TaskScheduleItemCompleteInput::from_completion_params(&BTreeMap::new(), &clock)
                .unwrap();
        assert_eq!(dto.actual_date, date!(2026-03-01));
        assert_eq!(dto.completed_at, datetime!(2026-03-01 12:00 UTC));
    }

    // Ruby: test "実施日が Date のときそのまま使う"
    #[test]
    fn actual_date_uses_provided_iso_date_string() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let mut params = BTreeMap::new();
        params.insert(
            "actual_date".into(),
            Value::String("2026-04-10".into()),
        );
        let dto =
            TaskScheduleItemCompleteInput::from_completion_params(&params, &clock).unwrap();
        assert_eq!(dto.actual_date, date!(2026-04-10));
    }

    // Ruby: test "不正な日付文字列は RecordInvalid"
    #[test]
    fn invalid_date_string_returns_record_invalid() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let mut params = BTreeMap::new();
        params.insert("actual_date".into(), Value::String("bogus".into()));
        let err =
            TaskScheduleItemCompleteInput::from_completion_params(&params, &clock).unwrap_err();
        assert!(!err.errors.as_ref().unwrap().get("actual_date").is_empty());
    }
}
