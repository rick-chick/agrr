//! Ruby: `Domain::CultivationPlan::Dtos::FieldCultivationCreateAttrs`

use std::collections::BTreeMap;

use serde_json::{json, Value};
use time::Date;

use super::field_cultivation_optimization_persist::FieldCultivationOptimizationPersist;

/// Ruby: `Domain::CultivationPlan::Dtos::FieldCultivationCreateAttrs`
#[derive(Debug, Clone)]
pub struct FieldCultivationCreateAttrs {
    pub cultivation_plan_field_id: i64,
    pub cultivation_plan_crop_id: i64,
    pub area: f64,
    pub start_date: Date,
    pub completion_date: Date,
    pub cultivation_days: i32,
    pub estimated_cost: f64,
    pub status: String,
    pub optimization_result: FieldCultivationOptimizationPersist,
}

impl FieldCultivationCreateAttrs {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        cultivation_plan_field_id: i64,
        cultivation_plan_crop_id: i64,
        area: f64,
        start_date: Date,
        completion_date: Date,
        cultivation_days: i32,
        estimated_cost: f64,
        status: impl Into<String>,
        optimization_result: FieldCultivationOptimizationPersist,
    ) -> Self {
        Self {
            cultivation_plan_field_id,
            cultivation_plan_crop_id,
            area,
            start_date,
            completion_date,
            cultivation_days,
            estimated_cost,
            status: status.into(),
            optimization_result,
        }
    }

    pub fn to_active_record_attributes(&self) -> BTreeMap<String, Value> {
        let opt = self.optimization_result.to_storage_hash();
        BTreeMap::from([
            (
                "cultivation_plan_field_id".into(),
                json!(self.cultivation_plan_field_id),
            ),
            (
                "cultivation_plan_crop_id".into(),
                json!(self.cultivation_plan_crop_id),
            ),
            ("area".into(), json!(self.area)),
            ("start_date".into(), json!(self.start_date.to_string())),
            (
                "completion_date".into(),
                json!(self.completion_date.to_string()),
            ),
            ("cultivation_days".into(), json!(self.cultivation_days)),
            ("estimated_cost".into(), json!(self.estimated_cost)),
            ("status".into(), json!(self.status)),
            ("optimization_result".into(), Value::Object(opt)),
        ])
    }
}

#[cfg(test)]
mod dtos_field_cultivation_create_attrs_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/dtos_field_cultivation_create_attrs_test.rs"));
}
