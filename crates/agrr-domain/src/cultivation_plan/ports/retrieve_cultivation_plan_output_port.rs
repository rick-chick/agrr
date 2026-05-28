//! Ruby: retrieve workbench output port.

use crate::cultivation_plan::dtos::CultivationPlanWorkbenchSnapshot;

pub trait RetrieveCultivationPlanOutputPort {
    fn on_success(&mut self, snapshot: CultivationPlanWorkbenchSnapshot);
    fn on_not_found(&mut self);
    fn on_unexpected(&mut self, message: &str);
}
