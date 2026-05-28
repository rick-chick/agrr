//! Ruby: `Domain::CultivationPlan::Ports::CultivationPlanDestroyOutputPort`

use crate::cultivation_plan::dtos::CultivationPlanDestroyOutput;
use crate::shared::dtos::Error;

pub trait CultivationPlanDestroyOutputPort {
    fn on_success(&mut self, dto: CultivationPlanDestroyOutput);
    fn on_failure(&mut self, error: Error);
}
