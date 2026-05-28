use crate::field_cultivation::dtos::FieldCultivationClimateDataInput;

pub trait FieldCultivationClimateDataInputPort {
    fn call(
        &mut self,
        input: FieldCultivationClimateDataInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
