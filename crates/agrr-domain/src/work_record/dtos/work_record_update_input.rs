//! Ruby: `Domain::WorkRecord::Dtos::WorkRecordUpdateInput`

use std::collections::BTreeMap;

use rust_decimal::Decimal;
use serde_json::Value;
use time::Date;

use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::ClockPort;
use crate::shared::type_converters::big_decimal_converter::cast_big_decimal_json;
use crate::work_record::dtos::work_record_create_input::record_invalid_field;

/// Partial update payload for an existing work record.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct WorkRecordUpdateInput {
    /// Client-supplied `updated_at` from the loaded record (optimistic lock token).
    pub expected_updated_at: Option<String>,
    pub name: Option<String>,
    pub actual_date: Option<Date>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub time_spent_minutes: Option<i64>,
    pub notes: Option<String>,
    /// `None` = omit from PATCH; `Some(None)` = clear FK; `Some(Some(id))` = set FK.
    pub fertilize_id: Option<Option<i64>>,
    /// `None` = omit from PATCH; `Some(None)` = clear FK; `Some(Some(id))` = set FK.
    pub pesticide_id: Option<Option<i64>>,
}

impl WorkRecordUpdateInput {
    pub fn from_params(
        params: &BTreeMap<String, Value>,
        _clock: &dyn ClockPort,
    ) -> Result<Self, RecordInvalidError> {
        if params.contains_key("task_schedule_item_id") {
            return Err(record_invalid_field(
                "task_schedule_item_id",
                "activerecord.errors.models.work_record.attributes.task_schedule_item_id.immutable",
            ));
        }

        let name = parse_optional_string(params.get("name"));
        let actual_date = match params.get("actual_date") {
            None | Some(Value::Null) => None,
            Some(Value::String(s)) if s.trim().is_empty() => None,
            Some(Value::String(s)) => Some(
                crate::cultivation_plan::helpers::parse_iso_date(s)
                    .ok_or_else(|| record_invalid_field("actual_date", "invalid date"))?,
            ),
            Some(_) => return Err(record_invalid_field("actual_date", "invalid date")),
        };
        let amount = cast_big_decimal_json(params.get("amount"));
        let amount_unit = parse_optional_string(params.get("amount_unit"));
        let time_spent_minutes = parse_optional_i64(params.get("time_spent_minutes"))?;
        let notes = parse_optional_string(params.get("notes"));
        let fertilize_id = if params.contains_key("fertilize_id") {
            Some(parse_optional_i64(params.get("fertilize_id"))?)
        } else {
            None
        };
        let pesticide_id = if params.contains_key("pesticide_id") {
            Some(parse_optional_i64(params.get("pesticide_id"))?)
        } else {
            None
        };
        let expected_updated_at = match params.get("updated_at") {
            None | Some(Value::Null) => None,
            Some(Value::String(s)) if s.trim().is_empty() => None,
            Some(Value::String(s)) => Some(s.clone()),
            Some(_) => {
                return Err(record_invalid_field(
                    "updated_at",
                    "activerecord.errors.models.work_record.attributes.updated_at.invalid",
                ));
            }
        };

        Ok(Self {
            expected_updated_at,
            name,
            actual_date,
            amount,
            amount_unit,
            time_spent_minutes,
            notes,
            fertilize_id,
            pesticide_id,
        })
    }
}

fn parse_optional_string(value: Option<&Value>) -> Option<String> {
    match value {
        None | Some(Value::Null) => None,
        Some(Value::String(s)) if s.trim().is_empty() => None,
        Some(Value::String(s)) => Some(s.clone()),
        _ => None,
    }
}

fn parse_optional_i64(value: Option<&Value>) -> Result<Option<i64>, RecordInvalidError> {
    match value {
        None | Some(Value::Null) => Ok(None),
        Some(Value::Number(n)) => n
            .as_i64()
            .map(Some)
            .ok_or_else(|| record_invalid_field("base", "invalid number")),
        Some(Value::String(s)) if s.trim().is_empty() => Ok(None),
        Some(Value::String(s)) => s
            .parse()
            .map(Some)
            .map_err(|_| record_invalid_field("base", "invalid number")),
        _ => Err(record_invalid_field("base", "invalid number")),
    }
}

#[cfg(test)]
mod work_record_update_input_test {
    use super::*;
    use crate::shared::ports::ClockPort;
    use serde_json::json;
    use time::macros::{date, datetime};
    use time::{Date, OffsetDateTime};

    struct FakeClock;

    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            date!(2026-06-12)
        }

        fn now(&self) -> OffsetDateTime {
            datetime!(2026-06-12 10:00 UTC)
        }
    }

    #[test]
    fn from_params_parses_updated_at_for_optimistic_locking() {
        let mut params = BTreeMap::new();
        params.insert("updated_at".into(), json!("2026-06-12T00:00:00Z"));
        params.insert("name".into(), json!("追肥"));

        let input = WorkRecordUpdateInput::from_params(&params, &FakeClock).expect("parse");
        assert_eq!(
            input.expected_updated_at.as_deref(),
            Some("2026-06-12T00:00:00Z")
        );
        assert_eq!(input.name.as_deref(), Some("追肥"));
    }

    #[test]
    fn from_params_rejects_missing_or_blank_updated_at() {
        let clock = FakeClock;
        let empty = WorkRecordUpdateInput::from_params(&BTreeMap::new(), &clock).expect("parse");
        assert!(empty.expected_updated_at.is_none());

        let mut blank = BTreeMap::new();
        blank.insert("updated_at".into(), json!("   "));
        let blank_input = WorkRecordUpdateInput::from_params(&blank, &clock).expect("parse");
        assert!(blank_input.expected_updated_at.is_none());
    }

    #[test]
    fn from_params_rejects_non_string_updated_at() {
        let mut params = BTreeMap::new();
        params.insert("updated_at".into(), json!(123));

        let err = WorkRecordUpdateInput::from_params(&params, &FakeClock)
            .expect_err("non-string updated_at");
        let errors = err.errors.expect("validation errors");
        assert!(!errors.get("updated_at").is_empty());
    }

    #[test]
    fn from_params_rejects_immutable_task_schedule_item_id() {
        let mut params = BTreeMap::new();
        params.insert("task_schedule_item_id".into(), json!(99));

        let err = WorkRecordUpdateInput::from_params(&params, &FakeClock)
            .expect_err("immutable task_schedule_item_id");
        let errors = err.errors.expect("validation errors");
        assert!(!errors.get("task_schedule_item_id").is_empty());
    }
}
