// Tests for `interactors/crop_masters_task_schedule_blueprint_create_interactor.rs`.

use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateFailure,
    MastersCropTaskScheduleBlueprintCreateFailureReason,
    MastersCropTaskScheduleBlueprintCreateInput,
};
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::entities::CropEntity;
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
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

fn agricultural_task() -> AgriculturalTaskEntity {
    AgriculturalTaskEntity {
        id: Some(3),
        user_id: Some(1),
        name: "T".into(),
        description: None,
        time_per_sqm: None,
        weather_dependency: None,
        required_tools: vec![],
        skill_level: None,
        region: None,
        task_type: Some(FIELD_WORK.into()),
        is_reference: false,
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
        stage_order: Some(1),
        stage_name: None,
        gdd_trigger: Some(Decimal::from(100)),
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
        stage_order: Some(1),
        stage_name: None,
        gdd_trigger: Some(Decimal::from(100)),
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



}

struct FoundAgriculturalTaskGw;

impl AgriculturalTaskGateway for FoundAgriculturalTaskGw {
    fn list_user_owned_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_reference_tasks(
        &self,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_user_and_reference_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_agricultural_task_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::agricultural_task::dtos::AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(agricultural_task())
    }

    fn find_by_reference_and_name(
        &self,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_user_id_and_name(
        &self,
        _: i64,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create(
        &self,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T,
    {
        block()
    }

    fn soft_delete_with_undo(
        &self,
        _: &User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<
        crate::agricultural_task::gateways::SoftDeleteUndoResult,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
}

struct MissingAgriculturalTaskGw;

impl AgriculturalTaskGateway for MissingAgriculturalTaskGw {
    fn list_user_owned_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_reference_tasks(
        &self,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_user_and_reference_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_agricultural_task_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::agricultural_task::dtos::AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err(Box::new(crate::shared::exceptions::RecordNotFoundError))
    }

    fn find_by_reference_and_name(
        &self,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_user_id_and_name(
        &self,
        _: i64,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create(
        &self,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T,
    {
        block()
    }

    fn soft_delete_with_undo(
        &self,
        _: &User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<
        crate::agricultural_task::gateways::SoftDeleteUndoResult,
        Box<dyn std::error::Error + Send + Sync>,
    > {
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

    fn delete_fertilize_blueprints_for_crop(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_regenerated_field_work(
        &self,
        _: i64,
        _: i64,
        _: &CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
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

    fn delete_fertilize_blueprints_for_crop(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_regenerated_field_work(
        &self,
        _: i64,
        _: i64,
        _: &CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

#[test]
fn should_create_blueprint_successfully_when_agricultural_task_exists_and_input_valid() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &FoundAgriculturalTaskGw,
        &SuccessBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(out.success);
    assert_eq!(out.failure, None);
}

#[test]
fn should_create_blueprint_without_gdd_and_stage_when_omitted() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &FoundAgriculturalTaskGw,
        &SuccessBlueprintGw,
        &user_lookup,
    );
    let mut input = valid_input();
    input.stage_order = None;
    input.gdd_trigger = None;
    interactor.call(input).unwrap();
    assert!(out.success);
    assert_eq!(out.failure, None);
}

#[test]
fn should_return_failure_when_agricultural_task_not_found() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &MissingAgriculturalTaskGw,
        &SuccessBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(!out.success);
    assert_eq!(
        out.failure,
        Some(MastersCropTaskScheduleBlueprintCreateFailureReason::AgriculturalTaskNotFound)
    );
}

#[test]
fn should_succeed_when_same_stage_and_task_but_different_gdd() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &FoundAgriculturalTaskGw,
        &DifferentGddBlueprintGw,
        &user_lookup,
    );
    interactor.call(valid_input()).unwrap();
    assert!(out.success);
    assert!(out.failure.is_none());
}

struct DifferentGddBlueprintGw;

impl CropMastersTaskScheduleBlueprintGateway for DifferentGddBlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![MastersCropTaskScheduleBlueprint {
            gdd_trigger: Some(Decimal::from(50)),
            ..existing_blueprint()
        }])
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

    fn delete_fertilize_blueprints_for_crop(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_regenerated_field_work(
        &self,
        _: i64,
        _: i64,
        _: &CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

#[test]
fn should_return_failure_when_duplicate_stage_order_task_and_gdd_exist() {
    let mut out = Spy {
        success: false,
        failure: None,
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintCreateInteractor::new(
        &mut out,
        &SuccessGw,
        &FoundAgriculturalTaskGw,
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
