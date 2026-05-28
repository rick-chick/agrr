//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldSourceSnapshot`

use super::plan_allocation_adjust_field_cultivation_allocation_snapshot::PlanAllocationAdjustFieldCultivationAllocationSnapshot;

/// Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldSourceSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustFieldSourceSnapshot {
    pub field_id: i64,
    pub field_name: String,
    pub field_area: f64,
    pub cultivations: Vec<PlanAllocationAdjustFieldCultivationAllocationSnapshot>,
}

impl PlanAllocationAdjustFieldSourceSnapshot {
    pub fn new(
        field_id: i64,
        field_name: impl Into<String>,
        field_area: f64,
        cultivations: Vec<PlanAllocationAdjustFieldCultivationAllocationSnapshot>,
    ) -> Self {
        Self {
            field_id,
            field_name: field_name.into(),
            field_area,
            cultivations,
        }
    }
}
