/// Test stub for [`CropGateway`] — all methods `unimplemented!()` unless overridden.
use crate::crop::dtos::{
    CropDeleteUsage, CropShowDetail, CropStageCreateInput, CropStageUpdateInput,
    NutrientRequirementUpdateInput, SunshineRequirementUpdateInput, TemperatureRequirementUpdateInput,
    ThermalRequirementUpdateInput,
};
use crate::crop::entities::{
    CropEntity, CropStageEntity, NutrientRequirementEntity, SunshineRequirementEntity,
    TemperatureRequirementEntity, ThermalRequirementEntity,
};
use crate::crop::gateways::{CropGateway, SoftDeleteWithUndoOutcome, UpdateMastersCropTaskTemplateOutcome};
use crate::shared::attr::AttrMap;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;
use serde_json::Value;

pub struct CropGatewayStub;

impl CropGateway for CropGatewayStub {
    fn list_index_for_filter(
        &self,
        _: &ReferenceIndexListFilter,
    ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_crop_show_detail(
        &self,
        _: i64,
    ) -> Result<CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_crop_record_with_stages(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn count_user_owned_non_reference_crops(
        &self,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_for_user(
        &self,
        _: &User,
        _: AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_for_user(
        &self,
        _: &User,
        _: i64,
        _: AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn soft_delete_with_undo(
        &self,
        _: &User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn list_by_is_reference(
        &self,
        _: bool,
        _: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_crop_stage(
        &self,
        _: CropStageCreateInput,
    ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_crop_stage(
        &self,
        _: i64,
        _: CropStageUpdateInput,
    ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_thermal_requirement(
        &self,
        _: i64,
        _: ThermalRequirementUpdateInput,
    ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_thermal_requirement(
        &self,
        _: i64,
        _: ThermalRequirementUpdateInput,
    ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_thermal_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_temperature_requirement(
        &self,
        _: i64,
        _: TemperatureRequirementUpdateInput,
    ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_temperature_requirement(
        &self,
        _: i64,
        _: TemperatureRequirementUpdateInput,
    ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_temperature_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_sunshine_requirement(
        &self,
        _: i64,
        _: SunshineRequirementUpdateInput,
    ) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_sunshine_requirement(
        &self,
        _: i64,
        _: SunshineRequirementUpdateInput,
    ) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_sunshine_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn create_nutrient_requirement(
        &self,
        _: i64,
        _: NutrientRequirementUpdateInput,
    ) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_nutrient_requirement(
        &self,
        _: i64,
        _: NutrientRequirementUpdateInput,
    ) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_nutrient_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn masters_crop_agricultural_task_templates_index_rows(
        &self,
        _: i64,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_masters_crop_task_template_for_api(
        &self,
        _: i64,
        _: i64,
        _: Value,
    ) -> Result<UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_masters_crop_task_template(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}
