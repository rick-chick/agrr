//! Ruby: `Domain::Crop::Interactors::CropMastersTaskTemplateDestroyInteractor`
use crate::crop::dtos::{MastersCropTaskTemplateDestroyInput, MastersCropTaskTemplateMastersFailure, MastersCropTaskTemplateMastersFailureReason};
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::CropMastersTaskTemplateDestroyOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskTemplateDestroyInteractor<'a, G, O, U> { output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U }
impl<'a, G, O, U> CropMastersTaskTemplateDestroyInteractor<'a, G, O, U>
where G: CropGateway, O: CropMastersTaskTemplateDestroyOutputPort, U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U) -> Self { Self { output_port, gateway, user_lookup } }
    pub fn call(&mut self, input: MastersCropTaskTemplateDestroyInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let failure = MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::CropNotFound);
        let crop_entity = match self.gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => { self.output_port.on_failure(failure); return Ok(()); }
            Err(e) => return Err(e),
        };
        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::CropNotFound));
            return Ok(());
        }
        match self.gateway.delete_masters_crop_task_template(input.crop_id, input.template_id) {
            Ok(()) => { self.output_port.on_success(); Ok(()) }
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::AssociationNotFound));
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::entities::CropEntity;
    use crate::shared::user::User;
    struct L(User); impl UserLookupGateway for L { fn find(&self, _: i64) -> User { self.0 } }
    struct O { ok: bool, fail: Option<MastersCropTaskTemplateMastersFailureReason> }
    impl CropMastersTaskTemplateDestroyOutputPort for O {
        fn on_success(&mut self) { self.ok = true; }
        fn on_failure(&mut self, f: MastersCropTaskTemplateMastersFailure) { self.fail = Some(f.reason); }
    }
    struct G { nf: bool }
    impl CropGateway for G {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropEntity { id: 1, user_id: Some(1), name: "c".into(), variety: None, is_reference: false, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None })
        }
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            if self.nf { Err(Box::new(RecordNotFoundError)) } else { Ok(()) }
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &User, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &User, _: i64, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    
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
    }
    // Ruby: test "should succeed when gateway destroys"
    #[test] fn succeed() {
        let mut o = O { ok: false, fail: None };
        let logger = L(User::new(1, false));
        let gw = G { nf: false };
        let mut i = CropMastersTaskTemplateDestroyInteractor::new(&mut o, &gw, &logger);
        i.call(MastersCropTaskTemplateDestroyInput { user_id: 1, crop_id: 1, template_id: 2 }).unwrap();
        assert!(o.ok);
    }
    // Ruby: test "should return association_not_found when gateway raises RecordNotFound"
    #[test] fn not_found() {
        let mut o = O { ok: false, fail: None };
        let logger = L(User::new(1, false));
        let gw = G { nf: true };
        let mut i = CropMastersTaskTemplateDestroyInteractor::new(&mut o, &gw, &logger);
        i.call(MastersCropTaskTemplateDestroyInput { user_id: 1, crop_id: 1, template_id: 2 }).unwrap();
        assert_eq!(o.fail, Some(MastersCropTaskTemplateMastersFailureReason::AssociationNotFound));
    }
}
