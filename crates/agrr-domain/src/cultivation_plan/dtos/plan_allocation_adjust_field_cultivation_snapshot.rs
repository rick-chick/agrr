//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldCultivationSnapshot`

use serde_json::Value;
use time::Date;

/// Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldCultivationSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustFieldCultivationSnapshot {
    pub field_cultivation_id: i64,
    pub field_id: i64,
    pub crop_id: i64,
    pub crop_name: String,
    pub variety: Option<String>,
    pub area: f64,
    pub start_date: Date,
    pub completion_date: Date,
    pub stored_cultivation_days: Option<i32>,
    pub crop_stage_count: i32,
    pub estimated_cost: Option<f64>,
    pub optimization_result: Option<Value>,
}

impl PlanAllocationAdjustFieldCultivationSnapshot {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        field_cultivation_id: i64,
        field_id: i64,
        crop_id: i64,
        crop_name: impl Into<String>,
        variety: Option<String>,
        area: f64,
        start_date: Date,
        completion_date: Date,
        stored_cultivation_days: Option<i32>,
        crop_stage_count: i32,
        estimated_cost: Option<f64>,
        optimization_result: Option<Value>,
    ) -> Self {
        Self {
            field_cultivation_id,
            field_id,
            crop_id,
            crop_name: crop_name.into(),
            variety,
            area,
            start_date,
            completion_date,
            stored_cultivation_days,
            crop_stage_count,
            estimated_cost,
            optimization_result,
        }
    }
}
