//! Ruby: `Domain::WorkRecord::Dtos::WorkRecordCreateInput`

use std::collections::BTreeMap;

use rust_decimal::Decimal;
use serde_json::Value;
use time::Date;

use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::ClockPort;
use crate::shared::type_converters::big_decimal_converter::cast_big_decimal_json;
use crate::shared::validation::ValidationErrors;

/// Parsed create params before schedule-item prefill.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordCreateInput {
    pub task_schedule_item_id: Option<i64>,
    pub field_cultivation_id: Option<i64>,
    pub agricultural_task_id: Option<i64>,
    pub name: Option<String>,
    pub task_type: Option<String>,
    pub actual_date: Date,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub time_spent_minutes: Option<i64>,
    pub notes: Option<String>,
}

impl WorkRecordCreateInput {
    pub fn from_params(
        params: &BTreeMap<String, Value>,
        clock: &dyn ClockPort,
    ) -> Result<Self, RecordInvalidError> {
        let task_schedule_item_id = parse_optional_i64(params.get("task_schedule_item_id"))?;
        let field_cultivation_id = parse_optional_i64(params.get("field_cultivation_id"))?;
        let agricultural_task_id = parse_optional_i64(params.get("agricultural_task_id"))?;
        let name = parse_optional_string(params.get("name"));
        let task_type = parse_optional_string(params.get("task_type"));
        let actual_date = coerce_actual_date(params.get("actual_date"), clock)?;
        let amount = cast_big_decimal_json(params.get("amount"));
        let amount_unit = parse_optional_string(params.get("amount_unit"));
        let time_spent_minutes = parse_optional_i64(params.get("time_spent_minutes"))?;
        let notes = parse_optional_string(params.get("notes"));

        let input = Self {
            task_schedule_item_id,
            field_cultivation_id,
            agricultural_task_id,
            name,
            task_type,
            actual_date,
            amount,
            amount_unit,
            time_spent_minutes,
            notes,
        };

        if input.task_schedule_item_id.is_none() {
            input.validate_ad_hoc_required_fields()?;
        }

        Ok(input)
    }

    fn validate_ad_hoc_required_fields(&self) -> Result<(), RecordInvalidError> {
        if self
            .name
            .as_ref()
            .map(|n| n.trim().is_empty())
            .unwrap_or(true)
        {
            return Err(record_invalid_field(
                "name",
                "activerecord.errors.models.work_record.attributes.name.blank",
            ));
        }
        Ok(())
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

fn coerce_actual_date(
    raw: Option<&Value>,
    clock: &dyn ClockPort,
) -> Result<Date, RecordInvalidError> {
    match raw {
        None | Some(Value::Null) => Ok(clock.today()),
        Some(Value::String(s)) if s.trim().is_empty() => Ok(clock.today()),
        Some(Value::String(s)) => crate::cultivation_plan::helpers::parse_iso_date(s)
            .ok_or_else(|| record_invalid_field("actual_date", "invalid date")),
        Some(_) => Err(record_invalid_field("actual_date", "invalid date")),
    }
}

pub(crate) fn record_invalid_field(attribute: &str, message: &str) -> RecordInvalidError {
    let mut errors = ValidationErrors::new();
    errors.add(attribute, message);
    RecordInvalidError::new(Some(message.to_string()), Some(errors))
}
