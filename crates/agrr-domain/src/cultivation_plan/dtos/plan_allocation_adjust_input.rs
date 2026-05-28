//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustInput`

use serde_json::Value;

use crate::cultivation_plan::dtos::CultivationPlanRestAuth;

#[derive(Debug, Clone, PartialEq)]
pub struct PlanAllocationAdjustInput {
    pub plan_id: i64,
    pub moves: Vec<Value>,
    pub auth: Option<CultivationPlanRestAuth>,
}

impl PlanAllocationAdjustInput {
    pub fn rest_adjust(&self) -> bool {
        self.auth.is_some()
    }
}
