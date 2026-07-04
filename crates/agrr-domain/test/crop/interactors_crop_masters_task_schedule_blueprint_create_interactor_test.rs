// Tests for `interactors/crop_masters_task_schedule_blueprint_create_interactor.rs`.

use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateFailure,
    MastersCropTaskScheduleBlueprintCreateFailureReason,
    MastersCropTaskScheduleBlueprintCreateInput,
};
use crate::crop::entities::{CropEntity, CropTaskTemplateEntity};
use crate::crop::gateways::{
    CropGateway, CropMastersTaskScheduleBlueprintGateway, CropMastersTaskTemplateGateway,
};
use crate::crop::interactors::crop_masters_task_schedule_blueprint_create_interactor::CropMastersTaskScheduleBlueprintCreateInteractor;
use crate::crop::policies::masters_crop_task_schedule_blueprint_create_policy::MANUAL_BLUEPRINT_SOURCE;
use crate::crop::ports::CropMastersTaskScheduleBlueprintCreateOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;
use rust_decimal::Decimal;

struct StubLookup(User);

impl UserLookupGateway for StubLookup {
    fn find(&self, _: i64) -> User {
        self.0
    }
}

struct Spy {
    success: bool,
    failure: Option<MastersCropTaskScheduleBlueprintCreateFailureReason>,
}

impl CropMastersTaskScheduleBlueprintCreateOutputPort for Spy {
    fn on_success(&mut self, _: MastersCropTaskScheduleBlueprint) {
        self.success = true;
    }

    fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintCreateFailure) {
        self.failure = Some(failure.reason);
    }
}

fn crop() -> CropEntity {
    CropEntity {
        id: 2,
        user_id: Some(1),
        name: "Foo".into(),
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

fn template() -> CropTaskTemplateEntity {
    CropTaskTemplateEntity {
        id: 10,
        crop_id: 2,
        agricultural_task_id: 3,
        name: "T".into(),
        description: None,
        time_per_sqm: None,
        weather_dependency: None,
        required_tools: vec![],
        skill_level: None,
        created_at: None,
        updated_at: None,
    }
}

fn valid_input() -> MastersCropTaskScheduleBlueprintCreateInput {
    MastersCropTaskScheduleBlueprintCreateInput {
        user_id: 1,
        crop_id: 2,
        agricultural_task_id: Some(3),
        stage_order: Some(1),
        stage_name: None,
        gdd_trigger: Some(100.0),
        task_type: None,
        description: None,
        priority: None,
    }
}

fn created_blueprint() -> MastersCropTaskScheduleBlueprint {
    MastersCropTaskScheduleBlueprint {
        id: 20,
        crop_id: 2,
        agricultural_task_id: Some(3),
        source_agricultural_task_id: None,
        stage_order: 1,
        stage_name: None,
        gdd_trigger: Decimal::from(100),
        gdd_tolerance: None,
        task_type: FIELD_WORK.into(),
        source: MANUAL_BLUEPRINT_SOURCE.into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: None,
        weather_dependency: None,
        time_per_sqm: None,
        name: None,
        created_at: None,
        updated_at: None,
    }
}

fn existing_blueprint() -> MastersCropTaskScheduleBlueprint {
    MastersCropTaskScheduleBlueprint {
        id: 99,
        crop_id: 2,
        agricultural_task_id: Some(3),
        source_agricultural_task_id: None,
        stage_order: 1,
        stage_name: None,
        gdd_trigger: Decimal::from(50),
        gdd_tolerance: None,
        task_type: FIELD_WORK.into(),
        source: MANUAL_BLUEPRINT_SOURCE.into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: None,
        weather_dependency: None,
        time_per_sqm: None,
        name: None,
        created_at: None,
        updated_at: None,
    }
}

struct SuccessGw;

impl CropGateway for SuccessGw {
    fn list_by_is_reference(
        &self,
        _: bool,
        _: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(crop())
    }

    fn list_index_for_filter(
        &self,
        _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_crop_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
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
    ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
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
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_crop_stage(
        &self,
        _: i64,
        _: crate::crop::dtos::CropStageUpdateInput,
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
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

struct RegisteredTemplateGw;

impl CropMastersTaskTemplateGateway for RegisteredTemplateGw {
    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<Option<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Some(template()))
    }

    fn create_detail(
        &self,
        _: i64,
        _: i64,
        _: crate::crop::dtos::CropTaskTemplatePersistAttributes,
    ) -> Result<CropTaskTemplateEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct MissingTemplateGw;

impl CropMastersTaskTemplateGateway for MissingTemplateGw {
    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<Option<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(None)
    }

    fn create_detail(
        &self,
        _: i64,
        _: i64,
        _: crate::crop::dtos::CropTaskTemplatePersistAttributes,
    ) -> Result<CropTaskTemplateEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct SuccessBlueprintGw;

impl CropMastersTaskScheduleBlueprintGateway for SuccessBlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }

    fn create(
        &self,
        _: CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        Ok(created_blueprint())
    }

    fn update(
        &self,
        _: i64,
        _: i64,
        _: serde_json::Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_by_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn replace_all_for_crop(
        &self,
        _: i64,
        _: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct DuplicateBlueprintGw;

impl CropMastersTaskScheduleBlueprintGateway for DuplicateBlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![existing_blueprint()])
    }

    fn create(
        &self,
        _: CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: i64,
        _: serde_json::Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_by_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn replace_all_for_crop(
        &self,
        _: i64,
        _: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

#[test]
fn should_create_blueprint_successfully_when_template_registered_and_input_valid() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &RegisteredTemplateGw,
        &SuccessBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(out.success);
    assert_eq!(out.failure, None);
}

#[test]
fn should_return_failure_when_task_template_not_registered() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &MissingTemplateGw,
        &SuccessBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(!out.success);
    assert_eq!(
        out.failure,
        Some(MastersCropTaskScheduleBlueprintCreateFailureReason::TaskTemplateNotRegistered)
    );
}

#[test]
fn should_return_failure_when_duplicate_stage_order_and_agricultural_task_id_exist() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &RegisteredTemplateGw,
        &DuplicateBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(!out.success);
    assert_eq!(
        out.failure,
        Some(MastersCropTaskScheduleBlueprintCreateFailureReason::Duplicate)
    );
}
