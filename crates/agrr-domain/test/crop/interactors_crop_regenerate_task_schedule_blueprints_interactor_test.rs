use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::dtos::{
    CropBlueprintAiFailure, CropBlueprintRegenerateFailureReason, CropRegenerateTaskScheduleBlueprintsInput,
    HttpStatus, MastersCropTaskScheduleBlueprint,
};
use crate::crop::entities::CropEntity;
use crate::crop::gateways::{
    CropAgrrRequirementGateway, CropGateway, CropMastersTaskScheduleBlueprintGateway,
};
use crate::crop::interactors::crop_regenerate_task_schedule_blueprints_interactor::CropRegenerateTaskScheduleBlueprintsInteractor;
use crate::crop::ports::{CropFertilizePlanAiQueryGateway, CropScheduleAiQueryGateway};
use crate::shared::exceptions::RecordNotFoundError;
use rust_decimal::Decimal;
use serde_json::json;
use std::str::FromStr;

struct TestHarness {
    crop_gw: CropGw,
    blueprint_gw: BlueprintGw,
    agricultural_task_gw: AgriculturalTaskGw,
    req_gw: ReqGw,
    schedule_gw: ScheduleGw,
    fertilize_gw: FertilizeGw,
}

impl TestHarness {
    fn interactor(
        &self,
    ) -> CropRegenerateTaskScheduleBlueprintsInteractor<
        '_,
        CropGw,
        BlueprintGw,
        ReqGw,
        AgriculturalTaskGw,
        ScheduleGw,
        FertilizeGw,
    > {
        CropRegenerateTaskScheduleBlueprintsInteractor::new(
            &self.crop_gw,
            &self.blueprint_gw,
            &self.agricultural_task_gw,
            &self.req_gw,
            &self.schedule_gw,
            &self.fertilize_gw,
        )
    }
}

struct CropGw {
    crop: Option<CropEntity>,
}

impl CropGateway for CropGw {
    fn list_index_for_filter(
        &self,
        _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.crop
            .clone()
            .ok_or_else(|| Box::new(RecordNotFoundError) as _)
    }
    fn find_crop_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn find_crop_record_with_stages(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn count_user_owned_non_reference_crops(
        &self,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }
    fn create_for_user(
        &self,
        _: &crate::shared::user::User,
        _: crate::shared::attr::AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn update_for_user(
        &self,
        _: &crate::shared::user::User,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn soft_delete_with_undo(
        &self,
        _: &crate::shared::user::User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<
        crate::crop::gateways::SoftDeleteWithUndoOutcome,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn list_by_is_reference(
        &self,
        _: bool,
        _: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn create_crop_stage(
        &self,
        _: crate::crop::dtos::CropStageCreateInput,
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn update_crop_stage(
        &self,
        _: i64,
        _: crate::crop::dtos::CropStageUpdateInput,
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn delete_crop_stage(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn create_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::ThermalRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn update_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::ThermalRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn delete_thermal_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn create_temperature_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::TemperatureRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::TemperatureRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn update_temperature_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::TemperatureRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::TemperatureRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn delete_temperature_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn create_sunshine_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::SunshineRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::SunshineRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn update_sunshine_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::SunshineRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::SunshineRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn delete_sunshine_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn create_nutrient_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::NutrientRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::NutrientRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn update_nutrient_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::NutrientRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::NutrientRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
    fn delete_nutrient_requirement(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
}

struct BlueprintGw {
    blueprints: Vec<MastersCropTaskScheduleBlueprint>,
}

impl CropMastersTaskScheduleBlueprintGateway for BlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.blueprints.clone())
    }
    fn create(
        &self,
        _: crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn update(
        &self,
        _: i64,
        _: i64,
        _: serde_json::Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn delete_by_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn replace_all_for_crop(
        &self,
        _: i64,
        _: &[crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn apply_regenerated_for_crop(
        &self,
        _: i64,
        _: &[crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.blueprints.clone())
    }
}

struct AgriculturalTaskGw {
    tasks: Vec<AgriculturalTaskEntity>,
}

impl AgriculturalTaskGateway for AgriculturalTaskGw {
    fn list_user_owned_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn list_reference_tasks(
        &self,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn list_user_and_reference_tasks(
        &self,
        _: i64,
        _: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn find_agricultural_task_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::agricultural_task::dtos::AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn find_by_id(
        &self,
        id: i64,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.tasks
            .iter()
            .find(|task| task.id == Some(id))
            .cloned()
            .ok_or_else(|| Box::new(RecordNotFoundError) as _)
    }
    fn find_by_reference_and_name(
        &self,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(None)
    }
    fn find_by_user_id_and_name(
        &self,
        _: i64,
        _: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(None)
    }
    fn create(
        &self,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn update(
        &self,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T,
    {
        block()
    }
    fn soft_delete_with_undo(
        &self,
        _: &crate::shared::user::User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<
        crate::agricultural_task::gateways::SoftDeleteUndoResult,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Err("unsupported".into())
    }
}

struct ReqGw {
    requirement: Option<serde_json::Value>,
}

impl CropAgrrRequirementGateway for ReqGw {
    fn build_for_crop_id(
        &self,
        _: i64,
    ) -> Result<Option<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.requirement.clone())
    }
}

struct ScheduleGw {
    response: Result<serde_json::Value, CropBlueprintAiFailure>,
}

impl CropScheduleAiQueryGateway for ScheduleGw {
    fn generate_schedule(
        &self,
        _: &str,
        _: &str,
        _: &serde_json::Value,
        _: &serde_json::Value,
    ) -> Result<serde_json::Value, CropBlueprintAiFailure> {
        match &self.response {
            Ok(v) => Ok(v.clone()),
            Err(e) => Err(e.clone()),
        }
    }
}

struct FertilizeGw {
    response: Result<serde_json::Value, CropBlueprintAiFailure>,
}

impl CropFertilizePlanAiQueryGateway for FertilizeGw {
    fn fetch_fertilize_plan(
        &self,
        _: &serde_json::Value,
        _: bool,
        _: u32,
    ) -> Result<serde_json::Value, CropBlueprintAiFailure> {
        match &self.response {
            Ok(v) => Ok(v.clone()),
            Err(e) => Err(e.clone()),
        }
    }
}

fn sample_crop() -> CropEntity {
    CropEntity {
        id: 1,
        user_id: Some(1),
        name: "トマト".into(),
        variety: Some("general".into()),
        is_reference: false,
        area_per_unit: None,
        revenue_per_area: None,
        region: None,
        groups: vec![],
        created_at: None,
        updated_at: None,
    }
}

fn sample_blueprint() -> MastersCropTaskScheduleBlueprint {
    MastersCropTaskScheduleBlueprint {
        id: 10,
        crop_id: 1,
        agricultural_task_id: Some(100),
        source_agricultural_task_id: None,
        stage_order: None,
        stage_name: None,
        gdd_trigger: None,
        gdd_tolerance: None,
        task_type: FIELD_WORK.into(),
        source: "manual".into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: None,
        weather_dependency: None,
        time_per_sqm: Some(Decimal::from_str("1.0").unwrap()),
        name: None,
        created_at: None,
        updated_at: None,
    }
}

fn sample_agricultural_task() -> AgriculturalTaskEntity {
    AgriculturalTaskEntity {
        id: Some(100),
        user_id: Some(1),
        name: "除草".into(),
        description: None,
        time_per_sqm: Some(1.0),
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

#[test]
fn regenerate_fails_when_blueprints_empty() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        blueprint_gw: BlueprintGw {
            blueprints: vec![],
        },
        agricultural_task_gw: AgriculturalTaskGw { tasks: vec![] },
        req_gw: ReqGw { requirement: None },
        schedule_gw: ScheduleGw {
            response: Ok(json!({})),
        },
        fertilize_gw: FertilizeGw {
            response: Ok(json!({})),
        },
    };
    let err = harness
        .interactor()
        .call(CropRegenerateTaskScheduleBlueprintsInput::new(1))
        .unwrap_err();
    assert_eq!(
        err.reason,
        CropBlueprintRegenerateFailureReason::MissingBlueprints
    );
}

#[test]
fn regenerate_succeeds_with_stub_ai_responses() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        blueprint_gw: BlueprintGw {
            blueprints: vec![sample_blueprint()],
        },
        agricultural_task_gw: AgriculturalTaskGw {
            tasks: vec![sample_agricultural_task()],
        },
        req_gw: ReqGw {
            requirement: Some(json!({"stage_requirements": [{"name": "stage1"}]})),
        },
        schedule_gw: ScheduleGw {
            response: Ok(json!({"task_schedules": [{"task_id": "100", "stage_order": 1, "gdd_trigger": "50"}]})),
        },
        fertilize_gw: FertilizeGw {
            response: Ok(json!({"schedule": []})),
        },
    };
    let rows = harness
        .interactor()
        .call(CropRegenerateTaskScheduleBlueprintsInput::new(1))
        .expect("regenerate");
    assert_eq!(rows.len(), 1);
}

#[test]
fn regenerate_maps_daemon_unavailable_to_ai_unavailable() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        blueprint_gw: BlueprintGw {
            blueprints: vec![sample_blueprint()],
        },
        agricultural_task_gw: AgriculturalTaskGw {
            tasks: vec![sample_agricultural_task()],
        },
        req_gw: ReqGw {
            requirement: Some(json!({"stage_requirements": []})),
        },
        schedule_gw: ScheduleGw {
            response: Err(CropBlueprintAiFailure::new(
                HttpStatus::ServiceUnavailable,
                "daemon down",
            )),
        },
        fertilize_gw: FertilizeGw {
            response: Ok(json!({})),
        },
    };
    let err = harness
        .interactor()
        .call(CropRegenerateTaskScheduleBlueprintsInput::new(1))
        .unwrap_err();
    assert_eq!(
        err.reason,
        CropBlueprintRegenerateFailureReason::AiUnavailable
    );
}
