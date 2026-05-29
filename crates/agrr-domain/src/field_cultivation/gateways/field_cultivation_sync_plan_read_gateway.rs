use crate::field_cultivation::dtos::{
    FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
};

/// Ruby: `FieldCultivationSyncPlanReadGateway`
pub trait FieldCultivationSyncPlanReadGateway: Send + Sync {
    fn list_sync_plan_field_ids_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_sync_plan_crop_entries_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<FieldCultivationSyncPlanCropEntry>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_sync_existing_field_cultivation_entries_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<FieldCultivationSyncExistingFieldCultivationEntry>, Box<dyn std::error::Error + Send + Sync>>;
}
