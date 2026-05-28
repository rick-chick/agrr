use crate::crop::entities::TemperatureRequirementEntity;

pub trait MastersTemperatureRequirementOutputPort {
    fn on_show_success(&mut self, entity: TemperatureRequirementEntity);
    fn on_create_success(&mut self, entity: TemperatureRequirementEntity);
    fn on_update_success(&mut self, entity: TemperatureRequirementEntity);
    fn on_destroy_success(&mut self);
    fn on_not_found(&mut self);
    fn on_already_exists(&mut self);
    fn on_validation_errors(&mut self, errors: Vec<String>);
}
