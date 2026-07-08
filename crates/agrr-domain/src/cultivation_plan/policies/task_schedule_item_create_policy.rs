//! Ruby: `Domain::CultivationPlan::Policies::TaskScheduleItemCreatePolicy`

use std::collections::BTreeMap;

use rust_decimal::Decimal;
use time::Date;

use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::cultivation_plan::dtos::TaskScheduleAgriculturalTaskSnapshot;
use crate::cultivation_plan::helpers::parse_iso_date;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::validation::ValidationErrors;

pub const CROP_REQUIRED_MESSAGE: &str = "作物を選択してください";
pub const INVALID_AGRICULTURAL_TASK_MESSAGE: &str = "選択した作業は利用できません";
pub const NAME_REQUIRED_MESSAGE: &str = "作業名を入力してください";
pub const INVALID_SCHEDULED_DATE_MESSAGE: &str = "無効な日付が指定されました";

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleItemCreateAttributes {
    pub field_cultivation_id: Option<i64>,
    pub task_type: String,
    pub name: String,
    pub description: Option<String>,
    pub scheduled_date: Option<String>,
    pub stage_name: Option<String>,
    pub stage_order: Option<i32>,
    pub priority: Option<i32>,
    pub source: String,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub agricultural_task_id: Option<i64>,
    pub cultivation_plan_crop_id: Option<i64>,
}

pub fn validate_crop_selection(
    field_cultivation_crop_id: Option<i64>,
    submitted_crop_id: Option<i64>,
) -> Result<(), RecordInvalidError> {
    let expected = field_cultivation_crop_id;
    let submitted = submitted_crop_id;

    if expected.is_none() && submitted.is_none() {
        return Ok(());
    }
    if let (Some(e), Some(s)) = (expected, submitted) {
        if e == s {
            return Ok(());
        }
    }
    raise_record_invalid(Some(CROP_REQUIRED_MESSAGE), None, None)
}

pub fn validate_agricultural_task(
    submitted_task_id: Option<i64>,
    task: Option<&TaskScheduleAgriculturalTaskSnapshot>,
) -> Result<(), RecordInvalidError> {
    if submitted_task_id.is_some() && task.is_none() {
        return raise_record_invalid(Some(INVALID_AGRICULTURAL_TASK_MESSAGE), None, None);
    }
    Ok(())
}

pub fn ensure_name_present(name: Option<&str>) -> Result<(), RecordInvalidError> {
    if present_str(name) {
        Ok(())
    } else {
        raise_record_invalid(None, Some(NAME_REQUIRED_MESSAGE), None)
    }
}

pub fn parse_scheduled_date(raw_value: &str) -> Result<Date, RecordInvalidError> {
    parse_iso_date(raw_value).ok_or_else(|| record_invalid_scheduled_date())
}

pub fn build_create_attributes(
    raw_params: &BTreeMap<String, Option<String>>,
    agricultural_task: Option<&TaskScheduleAgriculturalTaskSnapshot>,
) -> Result<TaskScheduleItemCreateAttributes, RecordInvalidError> {
    let name = raw_params
        .get("name")
        .and_then(|v| v.as_deref())
        .filter(|s| present_str(Some(s)))
        .map(str::to_string)
        .or_else(|| agricultural_task.map(|t| t.name.clone()));
    ensure_name_present(name.as_deref())?;

    let task_type = if let Some(task) = agricultural_task {
        task.task_type
            .clone()
            .unwrap_or_else(|| FIELD_WORK.to_string())
    } else {
        raw_params
            .get("task_type")
            .and_then(|v| v.clone())
            .filter(|s| present_str(Some(s.as_str())))
            .unwrap_or_else(|| FIELD_WORK.to_string())
    };

    let source = if agricultural_task.is_some() {
        "agricultural_task_entry"
    } else {
        "manual_entry"
    };

    Ok(TaskScheduleItemCreateAttributes {
        field_cultivation_id: parse_i64_param(raw_params.get("field_cultivation_id")),
        task_type,
        name: name.expect("ensure_name_present"),
        description: raw_params
            .get("description")
            .and_then(|v| v.clone())
            .filter(|s| present_str(Some(s.as_str())))
            .or_else(|| agricultural_task.and_then(|t| t.description.clone())),
        scheduled_date: raw_params.get("scheduled_date").and_then(|v| v.clone()),
        stage_name: raw_params.get("stage_name").and_then(|v| v.clone()),
        stage_order: parse_i32_param(raw_params.get("stage_order")),
        priority: parse_i32_param(raw_params.get("priority")),
        source: source.into(),
        weather_dependency: raw_params
            .get("weather_dependency")
            .and_then(|v| v.clone())
            .filter(|s| present_str(Some(s.as_str())))
            .or_else(|| agricultural_task.and_then(|t| t.weather_dependency.clone())),
        time_per_sqm: agricultural_task.and_then(|t| t.time_per_sqm),
        amount: None,
        amount_unit: raw_params.get("amount_unit").and_then(|v| v.clone()),
        agricultural_task_id: raw_params
            .get("agricultural_task_id")
            .and_then(|v| v.as_deref())
            .and_then(|s| s.parse().ok())
            .or_else(|| agricultural_task.map(|t| t.id)),
        cultivation_plan_crop_id: parse_i64_param(raw_params.get("cultivation_plan_crop_id")),
    })
}

fn parse_i64_param(value: Option<&Option<String>>) -> Option<i64> {
    value
        .and_then(|v| v.as_deref())
        .and_then(|s| s.parse().ok())
}

fn parse_i32_param(value: Option<&Option<String>>) -> Option<i32> {
    value
        .and_then(|v| v.as_deref())
        .and_then(|s| s.parse().ok())
}

fn record_invalid_scheduled_date() -> RecordInvalidError {
    let mut errors = ValidationErrors::new();
    errors.add("scheduled_date", INVALID_SCHEDULED_DATE_MESSAGE);
    RecordInvalidError::new(
        Some(INVALID_SCHEDULED_DATE_MESSAGE.into()),
        Some(errors),
    )
}

fn raise_record_invalid(
    base: Option<&str>,
    name: Option<&str>,
    scheduled_date: Option<&str>,
) -> Result<(), RecordInvalidError> {
    let mut errors = ValidationErrors::new();
    if let Some(m) = base {
        errors.add("base", m);
    }
    if let Some(m) = name {
        errors.add("name", m);
    }
    if let Some(m) = scheduled_date {
        errors.add("scheduled_date", m);
    }
    let message = errors.full_messages().into_iter().next();
    Err(RecordInvalidError::new(message, Some(errors)))
}

fn present_str(s: Option<&str>) -> bool {
    !blank_str(s)
}

fn blank_str(s: Option<&str>) -> bool {
    match s {
        None => true,
        Some(v) => v.trim().is_empty(),
    }
}

#[cfg(test)]
mod policies_task_schedule_item_create_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_task_schedule_item_create_policy_test.rs"));
}
