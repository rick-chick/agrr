use crate::field_cultivation::dtos::FieldCultivationClimateDataOutput;
use crate::shared::dtos::Error;

pub trait FieldCultivationClimateDataOutputPort {
    fn present(&mut self, data: FieldCultivationClimateDataOutput);
    fn on_error(&mut self, error: Error);
}
