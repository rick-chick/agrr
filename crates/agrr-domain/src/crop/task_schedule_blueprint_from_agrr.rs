//! Ruby: `Domain::Crop::TaskScheduleBlueprintFromAgrr`
use crate::agricultural_task::constants::schedule_item_types;
use crate::shared::type_converters::{cast_big_decimal, cast_integer};
use rust_decimal::Decimal;
use serde_json::{json, Value};

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleBlueprintRow {
    pub crop_id: i64,
    pub agricultural_task_id: i64,
    pub stage_order: Option<i64>,
    pub stage_name: Option<String>,
    pub gdd_trigger: Option<Decimal>,
    pub gdd_tolerance: Option<Decimal>,
    pub task_type: String,
    pub source: String,
    pub priority: Option<i64>,
    pub description: Option<String>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
}

pub fn general_row(
    crop_id: i64,
    task: &Value,
    agricultural_task_id: i64,
    template_description: Option<&str>,
    template_weather_dependency: Option<&str>,
    template_time_per_sqm: Option<Decimal>,
) -> TaskScheduleBlueprintRow {
    let agrr_task_name = task.get("name").or_else(|| task.get("description")).and_then(|v| v.as_str());
    TaskScheduleBlueprintRow {
        crop_id,
        agricultural_task_id,
        stage_order: integer_value(task.get("stage_order")),
        stage_name: task.get("stage_name").and_then(|v| v.as_str()).map(str::to_string),
        gdd_trigger: decimal_value(task.get("gdd_trigger").and_then(|v| v.as_str())),
        gdd_tolerance: decimal_value(task.get("gdd_tolerance").and_then(|v| v.as_str())),
        task_type: schedule_item_types::FIELD_WORK.to_string(),
        source: "agrr_schedule".into(),
        priority: integer_value(task.get("priority")),
        description: agrr_task_name.map(str::to_string).or_else(|| template_description.map(str::to_string)),
        amount: None,
        amount_unit: None,
        weather_dependency: task.get("weather_dependency").and_then(|v| v.as_str()).map(str::to_string).or_else(|| template_weather_dependency.map(str::to_string)),
        time_per_sqm: decimal_value(task.get("time_per_sqm").and_then(|v| v.as_str())).or(template_time_per_sqm),
    }
}

pub fn fertilizer_row(
    crop_id: i64,
    entry: &Value,
    index: usize,
    agricultural_task_id: i64,
    template_description: Option<&str>,
    template_weather_dependency: Option<&str>,
    template_time_per_sqm: Option<Decimal>,
) -> TaskScheduleBlueprintRow {
    let task_type = entry.get("task_type").and_then(|v| v.as_str()).map(str::to_string).unwrap_or_else(|| {
        if index == 0 { schedule_item_types::BASAL_FERTILIZATION.into() } else { schedule_item_types::TOPDRESS_FERTILIZATION.into() }
    });
    let fixed_stage_name = if index == 0 { "基肥" } else { "追肥" };
    let amount_raw = entry.get("amount_g_per_m2");
    let amount = decimal_value(amount_raw.and_then(|v| v.as_str()));
    TaskScheduleBlueprintRow {
        crop_id,
        agricultural_task_id,
        stage_order: integer_value(entry.get("stage_order")),
        stage_name: Some(fixed_stage_name.into()),
        gdd_trigger: decimal_value(entry.get("gdd_trigger").and_then(|v| v.as_str())),
        gdd_tolerance: decimal_value(entry.get("gdd_tolerance").and_then(|v| v.as_str())),
        task_type,
        source: "agrr_fertilize_plan".into(),
        priority: integer_value(entry.get("priority")),
        description: Some(fixed_stage_name.into()).or_else(|| template_description.map(str::to_string)),
        amount,
        amount_unit: entry.get("amount_unit").and_then(|v| v.as_str()).map(str::to_string).or_else(|| if amount_specified(amount_raw) { Some("g/m2".into()) } else { None }),
        weather_dependency: entry.get("weather_dependency").and_then(|v| v.as_str()).map(str::to_string).or_else(|| template_weather_dependency.map(str::to_string)),
        time_per_sqm: decimal_value(entry.get("time_per_sqm").and_then(|v| v.as_str())).or(template_time_per_sqm),
    }
}

pub fn decimal_value(value: Option<&str>) -> Option<Decimal> {
    cast_big_decimal(value)
}

pub fn integer_value(value: Option<&Value>) -> Option<i64> {
    cast_integer(value)
}

fn amount_specified(amount_raw: Option<&Value>) -> bool {
    match amount_raw {
        None | Some(Value::Null) => false,
        Some(Value::String(s)) => !s.is_empty(),
        _ => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    // Ruby: test "fertilizer_row assigns basal then topdress task types from index"
    #[test]
    fn fertilizer_row_assigns_basal_then_topdress_task_types_from_index() {
        let first = fertilizer_row(1, &json!({"task_id":"1","stage_order":0}), 0, 10, None, None, None);
        let second = fertilizer_row(1, &json!({"task_id":"2","stage_order":1}), 1, 11, None, None, None);
        assert_eq!(first.task_type, schedule_item_types::BASAL_FERTILIZATION);
        assert_eq!(second.task_type, schedule_item_types::TOPDRESS_FERTILIZATION);
        assert_eq!(first.stage_name.as_deref(), Some("基肥"));
        assert_eq!(second.stage_name.as_deref(), Some("追肥"));
    }

    // Ruby: test "general_row uses field_work task type"
    #[test]
    fn general_row_uses_field_work_task_type() {
        let row = general_row(5, &json!({"task_id":"9","stage_order":1,"gdd_trigger":0}), 9, None, None, None);
        assert_eq!(row.task_type, schedule_item_types::FIELD_WORK);
        assert_eq!(row.source, "agrr_schedule");
        assert_eq!(row.crop_id, 5);
    }

    // Ruby: test "integer_value and decimal_value coerce API-like strings"
    #[test]
    fn integer_and_decimal_value_coerce_api_like_strings() {
        assert_eq!(integer_value(Some(&json!("42"))), Some(42));
        assert_eq!(integer_value(Some(&json!("x"))), None);
        assert_eq!(decimal_value(Some("1.5")), Some(Decimal::from_str("1.5").unwrap()));
    }
}
