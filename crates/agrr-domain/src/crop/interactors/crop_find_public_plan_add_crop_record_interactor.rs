//! Ruby: `Domain::Crop::Interactors::CropFindPublicPlanAddCropRecordInteractor`
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_reference_record_policy;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::logger_port::LoggerPort;

pub trait CropFindPublicPlanAddCropRecordOutputPort {
    fn on_success(&mut self, crop: CropEntity);
    fn on_failure(&mut self, error: Error);
}

pub struct CropFindPublicPlanAddCropRecordInteractor<'a, O, G, L> {
    output_port: &'a mut O, gateway: &'a G, logger: &'a L,
}
impl<'a, O, G, L> CropFindPublicPlanAddCropRecordInteractor<'a, O, G, L>
where O: CropFindPublicPlanAddCropRecordOutputPort, G: CropGateway, L: LoggerPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, logger: &'a L) -> Self { Self { output_port, gateway, logger } }
    pub fn call(&mut self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if crop_id == 0 {
            self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
            self.output_port.on_failure(Error::new("Crop not found"));
            return Ok(());
        }
        let crop = match self.gateway.find_by_id(crop_id) {
            Ok(c) => c,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
                self.output_port.on_failure(Error::new("Crop not found")); return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_reference_record_policy::visible_for_public_plan_add_crop(&crop) {
            self.output_port.on_success(crop);
        } else {
            self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
            self.output_port.on_failure(Error::new("Crop not found"));
        }
        Ok(())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    struct Noop; impl LoggerPort for Noop { fn info(&self,_:&str){} fn warn(&self,_:&str){} fn error(&self,_:&str){} fn debug(&self,_:&str){} }
    struct O { ok: bool, fail: bool }
    impl CropFindPublicPlanAddCropRecordOutputPort for O {
        fn on_success(&mut self, _: CropEntity) { self.ok = true; }
        fn on_failure(&mut self, _: Error) { self.fail = true; }
    }
    fn crop(is_ref: bool) -> CropEntity {
        CropEntity { id: 1, user_id: None, name: "R".into(), variety: None, is_reference: is_ref, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None }
    }
    struct G { c: CropEntity, nf: bool }
    impl CropGateway for G {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.nf { Err(Box::new(RecordNotFoundError)) } else { Ok(self.c.clone()) }
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &crate::shared::user::User, _: i64, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    
    fn list_by_crop_id(&self, _: i64) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_crop_stage(&self, _: i64, _: crate::crop::dtos::CropStageUpdateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
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
    // Ruby: test "calls on_success when gateway returns reference crop"
    #[test] fn success() {
        let mut o = O { ok: false, fail: false };
        let g = G { c: crop(true), nf: false };
        let mut i = CropFindPublicPlanAddCropRecordInteractor::new(&mut o, &g, &Noop);
        i.call(1).unwrap(); assert!(o.ok);
    }
    // Ruby: test "calls on_failure when crop is not reference"
    #[test] fn not_reference() {
        let mut o = O { ok: false, fail: false };
        let g = G { c: crop(false), nf: false };
        let mut i = CropFindPublicPlanAddCropRecordInteractor::new(&mut o, &g, &Noop);
        i.call(1).unwrap(); assert!(o.fail);
    }
    // Ruby: test "calls on_failure when gateway raises RecordNotFound"
    #[test] fn record_not_found() {
        let mut o = O { ok: false, fail: false };
        let g = G { c: crop(true), nf: true };
        let mut i = CropFindPublicPlanAddCropRecordInteractor::new(&mut o, &g, &Noop);
        i.call(1).unwrap(); assert!(o.fail);
    }
}
