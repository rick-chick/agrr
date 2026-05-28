use crate::crop::entities::ThermalRequirementEntity;

pub trait MastersThermalRequirementOutputPort {
    fn on_show_success(&mut self, entity: ThermalRequirementEntity);
    fn on_create_success(&mut self, entity: ThermalRequirementEntity);
    fn on_update_success(&mut self, entity: ThermalRequirementEntity);
    fn on_destroy_success(&mut self);
    fn on_not_found(&mut self);
    fn on_already_exists(&mut self);
    fn on_validation_errors(&mut self, errors: Vec<String>);
}
