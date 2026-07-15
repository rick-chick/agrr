use crate::crop::dtos::{
    CropDeleteUsage, CropShowDetail, CropStageCreateInput, CropStageUpdateInput, NutrientRequirementUpdateInput,
    SunshineRequirementUpdateInput, TemperatureRequirementUpdateInput, ThermalRequirementUpdateInput,
};
use crate::crop::entities::{CropEntity, CropStageEntity, NutrientRequirementEntity, SunshineRequirementEntity, TemperatureRequirementEntity, ThermalRequirementEntity};
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;

/// Ruby: `Domain::Crop::Gateways::CropGateway`
pub trait CropGateway: Send + Sync {
    fn list_index_for_filter(&self, filter: &ReferenceIndexListFilter) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>>;
    fn find_by_id(&self, crop_id: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn find_crop_show_detail(&self, crop_id: i64) -> Result<CropShowDetail, Box<dyn std::error::Error + Send + Sync>>;
    fn find_crop_record_with_stages(&self, crop_id: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn count_user_owned_non_reference_crops(&self, user_id: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;
    fn create_for_user(&self, user: &User, attrs: AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_for_user(&self, user: &User, crop_id: i64, attrs: AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn find_delete_usage(&self, crop_id: i64) -> Result<CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>>;
    fn soft_delete_with_undo(&self, user: &User, crop_id: i64, auto_hide_after: i64, toast_message: &str) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_crop_id(&self, crop_id: i64) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>>;
    fn create_crop_stage(&self, input: CropStageCreateInput) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_crop_stage(&self, crop_stage_id: i64, input: CropStageUpdateInput) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn reorder_crop_stages(
        &self,
        crop_id: i64,
        stage_orders: Vec<(i64, i64)>,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let _ = (crop_id, stage_orders);
        Err("reorder_crop_stages not implemented".into())
    }
    fn delete_crop_stage(&self, crop_stage_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create_thermal_requirement(&self, crop_stage_id: i64, input: ThermalRequirementUpdateInput) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_thermal_requirement(&self, crop_stage_id: i64, input: ThermalRequirementUpdateInput) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn delete_thermal_requirement(&self, crop_stage_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create_temperature_requirement(&self, crop_stage_id: i64, input: TemperatureRequirementUpdateInput) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_temperature_requirement(&self, crop_stage_id: i64, input: TemperatureRequirementUpdateInput) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn delete_temperature_requirement(&self, crop_stage_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create_sunshine_requirement(&self, crop_stage_id: i64, input: SunshineRequirementUpdateInput) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_sunshine_requirement(&self, crop_stage_id: i64, input: SunshineRequirementUpdateInput) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn delete_sunshine_requirement(&self, crop_stage_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create_nutrient_requirement(&self, crop_stage_id: i64, input: NutrientRequirementUpdateInput) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn update_nutrient_requirement(&self, crop_stage_id: i64, input: NutrientRequirementUpdateInput) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>>;
    fn delete_nutrient_requirement(&self, crop_stage_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum SoftDeleteWithUndoOutcome {
    Success { undo: serde_json::Value },
    Failure(Error),
}

