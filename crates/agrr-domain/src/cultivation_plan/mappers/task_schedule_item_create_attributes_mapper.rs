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
    let mut pairs: Vec<(String, AttrValue)> = Vec::new();
    if let Some(id) = attrs.field_cultivation_id {
        pairs.push(("field_cultivation_id".into(), AttrValue::Int(id)));
    }
    pairs.push(("task_type".into(), AttrValue::Str(attrs.task_type.clone())));
    pairs.push(("name".into(), AttrValue::Str(attrs.name.clone())));
    if let Some(d) = &attrs.description {
        pairs.push(("description".into(), AttrValue::Str(d.clone())));
    }
    if let Some(d) = &attrs.scheduled_date {
        pairs.push(("scheduled_date".into(), AttrValue::Str(d.clone())));
    }
    if let Some(s) = &attrs.stage_name {
        pairs.push(("stage_name".into(), AttrValue::Str(s.clone())));
    }
    if let Some(v) = attrs.stage_order {
        pairs.push(("stage_order".into(), AttrValue::Int(i64::from(v))));
    }
    if let Some(v) = attrs.priority {
        pairs.push(("priority".into(), AttrValue::Int(i64::from(v))));
    }
    pairs.push(("source".into(), AttrValue::Str(attrs.source.clone())));
    if let Some(w) = &attrs.weather_dependency {
        pairs.push(("weather_dependency".into(), AttrValue::Str(w.clone())));
    }
    if let Some(v) = attrs.time_per_sqm {
        pairs.push(("time_per_sqm".into(), AttrValue::Str(v.to_string())));
    }
    if let Some(v) = attrs.amount {
        pairs.push(("amount".into(), AttrValue::Str(v.to_string())));
    }
    if let Some(u) = &attrs.amount_unit {
        pairs.push(("amount_unit".into(), AttrValue::Str(u.clone())));
    }
    if let Some(id) = attrs.agricultural_task_id {
        pairs.push(("agricultural_task_id".into(), AttrValue::Int(id)));
    }
    if let Some(id) = attrs.cultivation_plan_crop_id {
        pairs.push(("cultivation_plan_crop_id".into(), AttrValue::Int(id)));
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
