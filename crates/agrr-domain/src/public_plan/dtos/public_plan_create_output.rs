//! Ruby: `Domain::PublicPlan::Dtos::PublicPlanCreateOutput`

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PublicPlanCreateOutput {
    pub plan_id: i64,
}

impl PublicPlanCreateOutput {
    pub fn new(plan_id: i64) -> Self {
        Self { plan_id }
    }
}
