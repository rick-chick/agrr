use crate::crop::dtos::MastersCropTaskTemplateMastersFailure;
use serde_json::Value;

pub trait CropMastersTaskTemplateUpdateOutputPort {
    fn on_success(&mut self, row: Value);
    fn on_failure(&mut self, failure: MastersCropTaskTemplateMastersFailure);
}
