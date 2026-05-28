use crate::field_cultivation::dtos::FieldCultivationApiSummary;
use crate::shared::dtos::Error;

pub trait FieldCultivationApiShowOutputPort {
    fn on_success(&mut self, dto: FieldCultivationApiSummary);
    fn on_failure(&mut self, error: Error);
}
