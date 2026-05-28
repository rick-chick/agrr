use crate::field_cultivation::dtos::{
    FieldCultivationSyncApply, FieldCultivationSyncPlanSnapshot,
};

/// Ruby: `FieldCultivationSyncGateway`
pub trait FieldCultivationSyncGateway: Send + Sync {
    fn find_sync_plan_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<FieldCultivationSyncPlanSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn sync_by_plan_id(
        &self,
        plan_id: i64,
        sync_apply: &FieldCultivationSyncApply,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
