//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveHeaderSnapshot`

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveHeaderSnapshot`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PublicPlanSaveHeaderSnapshot {
    pub plan_id: i64,
    pub farm_id: Option<i64>,
}

impl PublicPlanSaveHeaderSnapshot {
    pub fn new(plan_id: i64, farm_id: Option<i64>) -> Self {
        Self { plan_id, farm_id }
    }
}
