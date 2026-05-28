use crate::crop::dtos::MastersCropTaskTemplateMastersFailure;
use serde_json::Value;

pub trait CropMastersTaskTemplateIndexOutputPort {
    fn on_success(&mut self, rows: Vec<Value>);
    fn on_failure(&mut self, failure: MastersCropTaskTemplateMastersFailure);
}
