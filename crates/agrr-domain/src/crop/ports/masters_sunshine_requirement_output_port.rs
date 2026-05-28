use crate::crop::entities::SunshineRequirementEntity;

pub trait MastersSunshineRequirementOutputPort {
    fn on_show_success(&mut self, entity: SunshineRequirementEntity);
    fn on_create_success(&mut self, entity: SunshineRequirementEntity);
    fn on_update_success(&mut self, entity: SunshineRequirementEntity);
    fn on_destroy_success(&mut self);
    fn on_not_found(&mut self);
    fn on_already_exists(&mut self);
    fn on_validation_errors(&mut self, errors: Vec<String>);
}
