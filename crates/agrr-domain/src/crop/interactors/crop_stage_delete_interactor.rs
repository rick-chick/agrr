//! Ruby: `Domain::Crop::Interactors::CropStageDeleteInteractor`
use crate::crop::dtos::{CropStageDeleteInput, CropStageDeleteOutput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropStageDeleteFailure, CropStageDeleteOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropStageDeleteInteractor<'a, G, O> { output_port: &'a mut O, gateway: &'a G }
impl<'a, G, O> CropStageDeleteInteractor<'a, G, O>
where G: CropGateway, O: CropStageDeleteOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self { Self { output_port, gateway } }
    pub fn call(&mut self, input: CropStageDeleteInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.delete_crop_stage(input.crop_stage_id) {
            Ok(()) => {
                self.output_port.on_success(CropStageDeleteOutput {
                    crop_stage_id: input.crop_stage_id,
                });
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(e) => { self.output_port.on_failure(CropStageDeleteFailure::Error(Error::new(e.to_string()))); Ok(()) }
                Err(err) => Err(err),
            },
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    struct Spy { ok: bool, fail: bool }
    impl CropStageDeleteOutputPort for Spy {
        fn on_success(&mut self, _: CropStageDeleteOutput) { self.ok = true; }
        fn on_failure(&mut self, _: CropStageDeleteFailure) { self.fail = true; }
    }
    struct Gw { invalid: bool, boom: bool }
    impl CropGateway for Gw {
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            if self.boom { return Err("boom".into()); }
            if self.invalid { return Err(Box::new(RecordInvalidError::new(Some("bad".into()), None))); }
            Ok(())
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &crate::shared::user::User, _: i64, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    
    fn list_by_crop_id(&self, _: i64) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_crop_stage(&self, _: i64, _: crate::crop::dtos::CropStageUpdateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_temperature_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_sunshine_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_nutrient_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn masters_crop_agricultural_task_templates_index_rows(&self, _: i64) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_masters_crop_task_template_for_api(&self, _: i64, _: i64, _: serde_json::Value) -> Result<crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    }
    // Ruby: test "calls on_success with delete result when gateway succeeds"
    #[test] fn success() { let mut s=Spy{ok:false,fail:false}; let mut i=CropStageDeleteInteractor::new(&mut s,&Gw{invalid:false,boom:false}); i.call(CropStageDeleteInput{crop_stage_id:1}).unwrap(); assert!(s.ok); }
    // Ruby: test "calls on_failure with Error when gateway raises RecordInvalid"
    #[test] fn invalid() { let mut s=Spy{ok:false,fail:false}; let mut i=CropStageDeleteInteractor::new(&mut s,&Gw{invalid:true,boom:false}); i.call(CropStageDeleteInput{crop_stage_id:1}).unwrap(); assert!(s.fail); }
    // Ruby: test "propagates StandardError when gateway raises"
    #[test] fn boom() { let mut s=Spy{ok:false,fail:false}; let mut i=CropStageDeleteInteractor::new(&mut s,&Gw{invalid:false,boom:true}); assert!(i.call(CropStageDeleteInput{crop_stage_id:1}).is_err()); }
}
