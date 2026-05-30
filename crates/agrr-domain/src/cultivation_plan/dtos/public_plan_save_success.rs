//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveSuccess`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanSaveSuccess {
    pub cultivation_plan_id: Option<i64>,
    pub plan_reused: bool,
}

impl PublicPlanSaveSuccess {
    pub fn new(cultivation_plan_id: Option<i64>, plan_reused: bool) -> Self {
        Self {
            cultivation_plan_id,
            plan_reused,
        }
    }
}
