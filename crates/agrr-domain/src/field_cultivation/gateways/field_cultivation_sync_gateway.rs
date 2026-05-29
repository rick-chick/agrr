use crate::field_cultivation::dtos::FieldCultivationSyncApply;

/// Ruby: `FieldCultivationSyncGateway`
pub trait FieldCultivationSyncGateway: Send + Sync {
    fn sync_by_plan_id(
        &self,
        plan_id: i64,
        sync_apply: &FieldCultivationSyncApply,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
