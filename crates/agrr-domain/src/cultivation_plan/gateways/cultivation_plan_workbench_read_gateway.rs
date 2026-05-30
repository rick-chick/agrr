//! Workbench snapshot load (without available crops).

use crate::cultivation_plan::dtos::cultivation_plan_workbench::CultivationPlanWorkbenchSnapshot;

pub trait CultivationPlanWorkbenchReadGateway: Send + Sync {
    fn load_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<CultivationPlanWorkbenchSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
