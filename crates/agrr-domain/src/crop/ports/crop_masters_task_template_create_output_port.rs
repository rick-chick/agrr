use crate::crop::dtos::{MastersCropTaskTemplate, MastersCropTaskTemplateCreateFailure};

pub trait CropMastersTaskTemplateCreateOutputPort {
    fn on_success(&mut self, dto: MastersCropTaskTemplate);
    fn on_failure(&mut self, failure: MastersCropTaskTemplateCreateFailure);
}
