use crate::crop::dtos::MastersCropTaskTemplateMastersFailure;

pub trait CropMastersTaskTemplateDestroyOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure: MastersCropTaskTemplateMastersFailure);
}
