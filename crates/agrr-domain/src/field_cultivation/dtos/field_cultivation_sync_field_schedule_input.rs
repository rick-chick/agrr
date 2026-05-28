use super::FieldCultivationSyncAllocationInput;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncFieldScheduleInput {
    pub field_id: Option<i64>,
    pub allocations: Vec<FieldCultivationSyncAllocationInput>,
}
