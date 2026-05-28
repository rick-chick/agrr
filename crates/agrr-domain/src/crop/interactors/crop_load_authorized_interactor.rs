//! Ruby: `Domain::Crop::Interactors::CropLoadAuthorizedInteractor`
use crate::crop::dtos::{AuthorizedCropLoaded, CropLoadAuthorizedInput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::CropLoadedAuthorizationFailurePort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;

pub struct CropLoadAuthorizedInteractor<'a, FP, G, U> {
    failure_presenter: &'a mut FP,
    user_id: i64,
    gateway: &'a G,
    user_lookup: &'a U,
}

impl<'a, FP, G, U> CropLoadAuthorizedInteractor<'a, FP, G, U>
where
    FP: CropLoadedAuthorizationFailurePort,
    G: CropGateway,
    U: UserLookupGateway,
{
    pub fn new(failure_presenter: &'a mut FP, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self { failure_presenter, user_id, gateway, user_lookup }
    }

    pub fn call(&mut self, input: CropLoadAuthorizedInput) -> Result<Option<AuthorizedCropLoaded>, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_entity = match self.gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };
        let auth_result = if input.for_edit {
            reference_record_authorization::assert_edit_allowed(&access_filter, &crop_entity)
        } else {
            reference_record_authorization::assert_view_allowed(&access_filter, &crop_entity)
        };
        if auth_result.is_err() {
            self.failure_presenter.on_permission_denied();
            return Ok(None);
        }
        Ok(Some(AuthorizedCropLoaded::new(crop_entity)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::entities::CropEntity;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup { fn find(&self, _: i64) -> User { self.0 } }
    struct NoFail;
    impl CropLoadedAuthorizationFailurePort for NoFail {
        fn on_permission_denied(&mut self) { panic!("must not call") }
        fn on_not_found(&mut self) { panic!("must not call") }
    }
    struct DenyFail { denied: std::cell::Cell<bool>, not_found: std::cell::Cell<bool> }
    impl CropLoadedAuthorizationFailurePort for DenyFail {
        fn on_permission_denied(&mut self) { self.denied.set(true); }
        fn on_not_found(&mut self) { self.not_found.set(true); }
    }
    fn crop(user_id: i64) -> CropEntity {
        CropEntity { id: 42, user_id: Some(user_id), name: "Foo".into(), variety: None, is_reference: false, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None }
    }
    struct Gw(CropEntity);
    impl CropGateway for Gw {
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { Ok(self.0.clone()) }
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
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    }

    // Ruby: test "returns authorized crop when gateway succeeds"
    #[test]
    fn returns_authorized_crop_when_gateway_succeeds() {
        let entity = crop(1);
        let gw = Gw(entity.clone());
        let mut fp = NoFail;
        let lookup = StubLookup(User::new(1, false));
        let mut i = CropLoadAuthorizedInteractor::new(&mut fp, 9, &gw, &lookup);
        let out = i.call(CropLoadAuthorizedInput::new(42, false)).unwrap().unwrap();
        assert_eq!(out.crop_entity, entity);
    }

    // Ruby: test "delegates to failure presenter on policy denial"
    #[test]
    fn delegates_to_failure_presenter_on_policy_denial() {
        let gw = Gw(crop(99));
        let mut fp = DenyFail { denied: std::cell::Cell::new(false), not_found: std::cell::Cell::new(false) };
        let lookup = StubLookup(User::new(1, false));
        let mut i = CropLoadAuthorizedInteractor::new(&mut fp, 9, &gw, &lookup);
        assert!(i.call(CropLoadAuthorizedInput::new(42, false)).unwrap().is_none());
        assert!(fp.denied.get());
    }

    // Ruby: test "delegates to failure presenter on record not found"
    #[test]
    fn delegates_to_failure_presenter_on_record_not_found() {
        struct MissingGw;
        impl CropGateway for MissingGw {
    
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { Err(Box::new(RecordNotFoundError)) }
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
            fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        }
        let mut fp = DenyFail { denied: std::cell::Cell::new(false), not_found: std::cell::Cell::new(false) };
        let lookup = StubLookup(User::new(1, false));
        let mut i = CropLoadAuthorizedInteractor::new(&mut fp, 9, &MissingGw, &lookup);
        assert!(i.call(CropLoadAuthorizedInput::new(42, false)).unwrap().is_none());
        assert!(fp.not_found.get());
    }
}
