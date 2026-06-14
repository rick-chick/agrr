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
    pub name: Option<String>,
    pub actual_date: Option<Date>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub time_spent_minutes: Option<i64>,
    pub notes: Option<String>,
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

        Ok(Self {
            name,
            actual_date,
            amount,
            amount_unit,
            time_spent_minutes,
            notes,
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
