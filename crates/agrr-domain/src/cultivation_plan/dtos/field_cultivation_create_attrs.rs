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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::OptimizationApplyAttrs;
    use time::macros::datetime;

    // Ruby: test "to_active_record_attributes nests optimization snapshot"
    #[test]
    fn to_active_record_attributes_nests_optimization_snapshot() {
        let allocation = json!({ "crop_id": "9", "area_used": 10.0 });
        let opt = FieldCultivationOptimizationPersist::new(11, 100.0, 40.0, allocation);
        let dto = FieldCultivationCreateAttrs::new(
            1,
            2,
            10.0,
            Date::from_calendar_date(2024, time::Month::April, 1).unwrap(),
            Date::from_calendar_date(2024, time::Month::June, 1).unwrap(),
            60,
            60.0,
            "completed",
            opt,
        );

        let h = dto.to_active_record_attributes();
        assert_eq!(h.get("cultivation_plan_field_id").and_then(|v| v.as_i64()), Some(1));
        let opt_h = h.get("optimization_result").unwrap().as_object().unwrap();
        let raw = opt_h.get("raw").unwrap().as_object().unwrap();
        assert_eq!(raw.get("crop_id").and_then(|v| v.as_str()), Some("9"));
        assert!(
            (opt_h
                .get("expected_revenue")
                .and_then(|v| v.as_f64())
                .unwrap()
                - 100.0)
                .abs()
                < 0.001
        );
    }

    // Ruby: test "optimization_apply_attrs maps keys for update"
    #[test]
    fn optimization_apply_attrs_maps_keys_for_update() {
        let dto = OptimizationApplyAttrs::new(
            1.0,
            2.0,
            3.0,
            datetime!(2026-01-01 00:00 UTC),
            "greedy",
            true,
            "{}",
        );
        let h = dto.to_active_record_attributes();
        assert!((h.get("total_profit").and_then(|v| v.as_f64()).unwrap() - 1.0).abs() < 0.001);
        assert_eq!(h.get("optimization_summary").and_then(|v| v.as_str()), Some("{}"));
        assert_eq!(h.get("is_optimal").and_then(|v| v.as_bool()), Some(true));
    }
}
