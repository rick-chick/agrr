use crate::public_plan::dtos::{
    PublicPlanCreateNoCropsViewContext, PublicPlanCreateOutput,
};
use crate::shared::dtos::Error;

/// Ruby: `Domain::PublicPlan::Ports::PublicPlanCreateOutputPort`
pub trait PublicPlanCreateOutputPort {
    fn on_success(&mut self, success_dto: PublicPlanCreateOutput);
    fn on_failure(&mut self, failure_dto: Error);
    fn on_no_crops_failure(&mut self, view_context: PublicPlanCreateNoCropsViewContext);
}
