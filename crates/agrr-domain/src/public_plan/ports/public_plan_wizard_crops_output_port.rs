use crate::crop::entities::CropEntity;
use crate::shared::dtos::Error;

/// Ruby: `Domain::PublicPlan::Ports::PublicPlanWizardCropsOutputPort`
pub trait PublicPlanWizardCropsOutputPort {
    fn on_success(&mut self, crops: Vec<CropEntity>);
    fn on_farm_not_found(&mut self);
    fn on_failure(&mut self, error: Error);
}
