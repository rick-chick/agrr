use crate::field_cultivation::dtos::FieldCultivationSyncInput;

pub trait FieldCultivationSyncInputPort: Send + Sync {
    fn call(
        &mut self,
        plan_id: i64,
        sync_input: FieldCultivationSyncInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
