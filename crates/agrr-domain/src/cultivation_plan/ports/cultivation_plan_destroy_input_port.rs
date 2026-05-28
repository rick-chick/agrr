//! Ruby: `Domain::CultivationPlan::Ports::CultivationPlanDestroyInputPort`

pub trait CultivationPlanDestroyInputPort: Send + Sync {
    fn call(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
