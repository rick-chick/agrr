use crate::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
};
use serde_json::Value;

/// Ruby: masters crop task schedule blueprint persistence.
pub trait CropMastersTaskScheduleBlueprintGateway: Send + Sync {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        attrs: CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        crop_id: i64,
        blueprint_id: i64,
        attributes: Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_by_id(
        &self,
        crop_id: i64,
        blueprint_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn replace_all_for_crop(
        &self,
        crop_id: i64,
        records: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>;

    /// Merge AI regeneration: update field-work rows in place, replace fertilize rows.
    fn apply_regenerated_for_crop(
        &self,
        crop_id: i64,
        records: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>;
}
