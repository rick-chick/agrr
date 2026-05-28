//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldCultivationAllocationSnapshot`

use time::Date;

/// Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldCultivationAllocationSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustFieldCultivationAllocationSnapshot {
    pub field_cultivation_id: i64,
    pub field_id: i64,
    pub crop_id: String,
    pub crop_name: String,
    pub variety: Option<String>,
    pub area: f64,
    pub start_date: Date,
    pub completion_date: Date,
    pub cultivation_days: i32,
    pub estimated_cost: f64,
    pub revenue: f64,
    pub accumulated_gdd: f64,
    pub has_growth_stages: bool,
}

impl PlanAllocationAdjustFieldCultivationAllocationSnapshot {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        field_cultivation_id: i64,
        field_id: i64,
        crop_id: impl Into<String>,
        crop_name: impl Into<String>,
        variety: Option<String>,
        area: f64,
        start_date: Date,
        completion_date: Date,
        cultivation_days: i32,
        estimated_cost: f64,
        revenue: f64,
        accumulated_gdd: f64,
        has_growth_stages: bool,
    ) -> Self {
        Self {
            field_cultivation_id,
            field_id,
            crop_id: crop_id.into(),
            crop_name: crop_name.into(),
            variety,
            area,
            start_date,
            completion_date,
            cultivation_days,
            estimated_cost,
            revenue,
            accumulated_gdd,
            has_growth_stages,
        }
    }
}
