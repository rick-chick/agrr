//! Ruby: `Domain::Crop::Interactors::CropLoadMastersAuthorizedCropStageInteractor`

use crate::crop::dtos::{AuthorizedCropStageInCropContext, CropLoadAuthorizedCropStageInput};
use crate::crop::gateways::{CropGateway, CropStageGateway};
use crate::crop::ports::CropLoadedAuthorizationFailurePort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;

pub struct CropLoadMastersAuthorizedCropStageInteractor<'a, FP, CG, SG, U> {
    failure_presenter: &'a mut FP,
    user_id: i64,
    crop_gateway: &'a CG,
    crop_stage_gateway: &'a SG,
    user_lookup: &'a U,
}

impl<'a, FP, CG, SG, U> CropLoadMastersAuthorizedCropStageInteractor<'a, FP, CG, SG, U>
where
    FP: CropLoadedAuthorizationFailurePort,
    CG: CropGateway,
    SG: CropStageGateway,
    U: UserLookupGateway,
{
    pub fn new(
        failure_presenter: &'a mut FP,
        user_id: i64,
        crop_gateway: &'a CG,
        crop_stage_gateway: &'a SG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            failure_presenter,
            user_id,
            crop_gateway,
            crop_stage_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: CropLoadAuthorizedCropStageInput,
    ) -> Result<Option<AuthorizedCropStageInCropContext>, Box<dyn std::error::Error + Send + Sync>>
    {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };

        let crop_stage_entity = match self.crop_stage_gateway.find_by_id(input.crop_stage_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };

        if crop_stage_entity.crop_id != crop_entity.id {
            self.failure_presenter.on_not_found();
            return Ok(None);
        }

        if reference_record_authorization::assert_edit_allowed(&access_filter, &crop_entity)
            .is_err()
        {
            self.failure_presenter.on_not_found();
            return Ok(None);
        }

        Ok(Some(AuthorizedCropStageInCropContext::new(
            crop_entity,
            crop_stage_entity,
        )))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::entities::{CropEntity, CropStageEntity};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct NoFail;
    impl CropLoadedAuthorizationFailurePort for NoFail {
        fn on_permission_denied(&mut self) {}
        fn on_not_found(&mut self) {
            panic!("must not call")
        }
    }

    fn crop() -> CropEntity {
        CropEntity {
            id: 1,
            user_id: Some(1),
            name: "x".into(),
            variety: None,
            is_reference: false,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    struct Cg(CropEntity);
    impl CropGateway for Cg {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.0.clone())
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
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
            _: crate::shared::attr::AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::crop::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::ThermalRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::ThermalRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_temperature_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_sunshine_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_nutrient_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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

    struct Sg(CropStageEntity);
    impl CropStageGateway for Sg {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.0.clone())
        }
    }

    // Ruby: test "returns bundle when crop and stage match"
    #[test]
    fn returns_bundle_when_crop_and_stage_match() {
        let stage = CropStageEntity::new(2, 1, "s", 1).unwrap();
        let mut fp = NoFail;
        let cg = Cg(crop());
        let sg = Sg(stage.clone());
        let user_lookup = StubLookup(User::new(1, false));
        let mut i = CropLoadMastersAuthorizedCropStageInteractor::new(
            &mut fp,
            9,
            &cg,
            &sg,
            &user_lookup,
        );
        let out = i
            .call(CropLoadAuthorizedCropStageInput::new(1, 2, false))
            .unwrap()
            .unwrap();
        assert_eq!(out.crop_entity.id, 1);
        assert_eq!(out.crop_stage_entity.id, 2);
    }
}
