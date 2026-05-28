//! Private plan list/detail output ports.

use crate::cultivation_plan::dtos::{PrivateCultivationPlanDetail, PrivatePlanIndexPlanRow};
use crate::shared::dtos::Error;

pub trait PrivateOwnedPlansListOutputPort {
    fn on_success(&mut self, rows: Vec<PrivatePlanIndexPlanRow>);
    fn on_failure(&mut self, error: Error);
}

pub trait PrivateOwnedPlanDetailOutputPort {
    fn on_success(&mut self, detail: PrivateCultivationPlanDetail);
    fn on_not_found(&mut self);
    fn on_failure(&mut self, error: Error);
}
