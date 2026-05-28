//! Ruby: `Domain::Crop::Interactors::CropDetailInteractor`

use crate::crop::dtos::CropDetailOutput;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropDetailOutputPort, DetailFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;

pub struct CropDetailInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> CropDetailInteractor<'a, G, O, U>
where
    G: CropGateway,
    O: CropDetailOutputPort,
    U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_detail = match self.gateway.find_crop_show_detail(crop_id) {
            Ok(detail) => detail,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &crop_detail.crop)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port
            .on_success(CropDetailOutput::new(crop_detail.crop));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::dtos::CropShowDetail;
    use crate::crop::entities::CropEntity;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct SpyOutput {
        success: Option<CropDetailOutput>,
        failure: Option<DetailFailure>,
    }

    impl CropDetailOutputPort for SpyOutput {
        fn on_success(&mut self, output: CropDetailOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    fn crop(user_id: i64) -> CropEntity {
        CropEntity {
            id: 5,
            user_id: Some(user_id),
            name: "Tomato".into(),
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

    struct DetailGateway {
        entity: CropEntity,
    }

    impl CropGateway for DetailGateway {
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropShowDetail {
                crop: self.entity.clone(),
            })
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

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
        ) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>>
        {
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

    // Ruby: test "calls on_success with crop detail dto when gateway succeeds"
    #[test]
    fn calls_on_success_with_crop_detail_dto_when_gateway_succeeds() {
        let entity = crop(10);
        let gateway = DetailGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(10, false));
        let mut interactor =
            CropDetailInteractor::new(&mut output, 10, &gateway, &user_lookup_1);
        interactor.call(5).unwrap();
        assert_eq!(output.success, Some(CropDetailOutput::new(entity)));
    }

    // Ruby: test "calls on_failure with policy exception when permission is denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_is_denied() {
        let gateway = DetailGateway { entity: crop(99) };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(10, false));
        let mut interactor =
            CropDetailInteractor::new(&mut output, 10, &gateway, &user_lookup_1);
        interactor.call(5).unwrap();
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
