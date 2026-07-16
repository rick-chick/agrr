use serde_json::json;

use crate::crop::dtos::{
    CropSetupProposalApplyResult, CropSetupProposalInput, CropSetupProposalMode,
    CropSetupProposalValidationError,
};
use crate::crop::entities::{CropEntity, CropStageEntity};
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway, CropSetupProposalGateway};
use crate::crop::interactors::crop_setup_proposal_interactor::CropSetupProposalInteractor;
use crate::crop::ports::CropSetupProposalOutputPort;
use crate::shared::user::User;

struct TestCropGateway {
    crop: CropEntity,
    stages: Vec<CropStageEntity>,
}

impl CropGateway for TestCropGateway {
    fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.crop.clone())
    }

    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.stages.clone())
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
    ) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn list_by_is_reference(
        &self,
        _: bool,
        _: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
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
    ) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
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
    ) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update_temperature_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::TemperatureRequirementUpdateInput,
    ) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
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
    ) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update_sunshine_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::SunshineRequirementUpdateInput,
    ) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
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
    ) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update_nutrient_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::NutrientRequirementUpdateInput,
    ) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn delete_nutrient_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct TestBlueprintGateway;

impl CropMastersTaskScheduleBlueprintGateway for TestBlueprintGateway {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<crate::crop::dtos::MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(vec![])
    }

    fn create(
        &self,
        _: crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<crate::crop::dtos::MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: i64,
        _: serde_json::Value,
    ) -> Result<crate::crop::dtos::MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn delete_by_id(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn replace_all_for_crop(
        &self,
        _: i64,
        _: &[crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<crate::crop::dtos::MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>
    {
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
        _: &crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<crate::crop::dtos::MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }
}

struct TestAgriculturalTaskGateway;

impl crate::agricultural_task::gateways::AgriculturalTaskGateway for TestAgriculturalTaskGateway {
    fn list_user_owned_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<crate::agricultural_task::entities::AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn list_reference_tasks(
        &self,
        _: Option<&str>,
    ) -> Result<Vec<crate::agricultural_task::entities::AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn list_user_and_reference_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<crate::agricultural_task::entities::AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn find_agricultural_task_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::agricultural_task::dtos::AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<crate::agricultural_task::entities::AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn find_by_reference_and_name(
        &self,
        _: &str,
    ) -> Result<Option<crate::agricultural_task::entities::AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn find_by_user_id_and_name(
        &self,
        _: i64,
        _: &str,
    ) -> Result<Option<crate::agricultural_task::entities::AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn create(
        &self,
        _: crate::shared::attr::AttrMap,
    ) -> Result<crate::agricultural_task::entities::AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<crate::agricultural_task::entities::AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>
    {
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
    ) -> Result<crate::agricultural_task::gateways::SoftDeleteUndoResult, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }
}

struct TestProposalGateway;

impl CropSetupProposalGateway for TestProposalGateway {
    fn apply_plan(
        &self,
        _: i64,
        _: i64,
        _: &crate::crop::dtos::CropSetupProposalPlan,
    ) -> Result<CropSetupProposalApplyResult, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!("apply should not run in dry_run test")
    }
}

struct TestUserLookup {
    user: User,
}

impl crate::shared::gateways::UserLookupGateway for TestUserLookup {
    fn find(&self, _: i64) -> User {
        self.user.clone()
    }
}

struct TestPort {
    dry_run_called: bool,
}

impl CropSetupProposalOutputPort for TestPort {
    fn on_dry_run_success(&mut self, _: serde_json::Value) {
        self.dry_run_called = true;
    }

    fn on_validation_failure(&mut self, _: Vec<CropSetupProposalValidationError>) {}

    fn on_apply_success(&mut self, _: CropSetupProposalApplyResult, _: serde_json::Value) {}

    fn on_crop_not_found(&mut self) {}
}

#[test]
fn dry_run_returns_success_without_apply_gateway() {
    let crop = CropEntity::new(1, "トマト", Some(1), false).expect("crop");
    let crop_gateway = TestCropGateway {
        crop,
        stages: vec![],
    };
    let blueprint_gateway = TestBlueprintGateway;
    let agricultural_task_gateway = TestAgriculturalTaskGateway;
    let proposal_gateway = TestProposalGateway;
    let user_lookup = TestUserLookup {
        user: User::new(1, false),
    };
    let mut port = TestPort {
        dry_run_called: false,
    };

    let mut interactor = CropSetupProposalInteractor::new(
        &mut port,
        &crop_gateway,
        &blueprint_gateway,
        &agricultural_task_gateway,
        &proposal_gateway,
        &user_lookup,
    );

    let body = json!({
        "stages": [{
            "name": "育苗",
            "order": 1,
            "thermal_requirement": { "required_gdd": "120" }
        }],
        "agricultural_tasks": [{
            "ref": "task-weeding",
            "name": "除草",
            "task_type": "field_work",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "task-weeding",
            "stage_order": 1,
            "gdd_trigger": 0,
            "task_type": "field_work"
        }]
    });

    interactor
        .call(CropSetupProposalInput::new(1, 1, CropSetupProposalMode::DryRun, body))
        .expect("interactor");

    assert!(port.dry_run_called);
}
