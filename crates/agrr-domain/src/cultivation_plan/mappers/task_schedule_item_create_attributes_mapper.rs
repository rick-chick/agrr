//! Ruby: `Domain::CultivationPlan::Mappers::TaskScheduleItemCreateAttributesMapper`

use std::collections::BTreeMap;

use crate::cultivation_plan::policies::task_schedule_item_create_policy::TaskScheduleItemCreateAttributes;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};

pub fn attrs_to_params(attrs: &AttrMap) -> BTreeMap<String, Option<String>> {
    attrs
        .iter()
        .map(|(k, v)| {
            let val = match v {
                AttrValue::Str(s) => Some(s.clone()),
                AttrValue::Int(i) => Some(i.to_string()),
                AttrValue::Bool(b) => Some(b.to_string()),
                AttrValue::Null => None,
            };
            (k.clone(), val)
        })
        .collect()
}

pub fn create_attrs_to_attr_map(attrs: &TaskScheduleItemCreateAttributes) -> AttrMap {
    let mut pairs = Vec::new();
    if let Some(id) = attrs.field_cultivation_id {
        pairs.push(("field_cultivation_id".to_string(), AttrValue::Int(id)));
    }
    pairs.push(("task_type".to_string(), AttrValue::Str(attrs.task_type.clone())));
    pairs.push(("name".to_string(), AttrValue::Str(attrs.name.clone())));
    if let Some(d) = &attrs.description {
        pairs.push(("description".to_string(), AttrValue::Str(d.clone())));
    }
    if let Some(d) = &attrs.scheduled_date {
        pairs.push(("scheduled_date".to_string(), AttrValue::Str(d.clone())));
    }
    if let Some(s) = &attrs.stage_name {
        pairs.push(("stage_name".to_string(), AttrValue::Str(s.clone())));
    }
    if let Some(order) = attrs.stage_order {
        pairs.push(("stage_order".to_string(), AttrValue::Int(i64::from(order))));
    }
    if let Some(priority) = attrs.priority {
        pairs.push(("priority".to_string(), AttrValue::Int(i64::from(priority))));
    }
    pairs.push(("source".to_string(), AttrValue::Str(attrs.source.clone())));
    if let Some(w) = &attrs.weather_dependency {
        pairs.push(("weather_dependency".to_string(), AttrValue::Str(w.clone())));
    }
    if let Some(t) = attrs.time_per_sqm {
        pairs.push(("time_per_sqm".to_string(), AttrValue::Str(t.to_string())));
    }
    if let Some(a) = attrs.amount {
        pairs.push(("amount".to_string(), AttrValue::Str(a.to_string())));
    }
    if let Some(u) = &attrs.amount_unit {
        pairs.push(("amount_unit".to_string(), AttrValue::Str(u.clone())));
    }
    if let Some(id) = attrs.agricultural_task_id {
        pairs.push(("agricultural_task_id".to_string(), AttrValue::Int(id)));
    }
    if let Some(id) = attrs.cultivation_plan_crop_id {
        pairs.push(("cultivation_plan_crop_id".to_string(), AttrValue::Int(id)));
    }
    attr_map_from_pairs(pairs)
}

#[cfg(test)]
mod mappers_task_schedule_item_create_attributes_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/mappers_task_schedule_item_create_attributes_mapper_test.rs"
    ));
}
