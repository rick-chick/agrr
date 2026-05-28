//! Ruby: `Domain::CultivationPlan::Ports::PlanAllocationAdjustOutputPort`

use crate::cultivation_plan::dtos::{PlanAllocationAdjustFailure, PlanAllocationAdjustOutput};

pub trait PlanAllocationAdjustOutputPort: Send + Sync {
    fn on_success(&mut self, output: PlanAllocationAdjustOutput);
    fn on_failure(&mut self, failure: PlanAllocationAdjustFailure);
}
