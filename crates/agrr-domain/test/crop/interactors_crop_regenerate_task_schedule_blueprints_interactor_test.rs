use crate::crop::dtos::{
    CropBlueprintAiFailure, CropBlueprintRegenerateFailureReason, CropRegenerateTaskScheduleBlueprintsInput,
    HttpStatus,
};
use crate::crop::entities::{CropEntity, CropTaskTemplateEntity};
use crate::crop::gateways::{
    CropAgrrRequirementGateway, CropGateway, CropMastersTaskScheduleBlueprintGateway,
    CropMastersTaskTemplateGateway,
};
use crate::crop::interactors::crop_regenerate_task_schedule_blueprints_interactor::CropRegenerateTaskScheduleBlueprintsInteractor;
use crate::crop::ports::{CropFertilizePlanAiQueryGateway, CropScheduleAiQueryGateway};
use crate::shared::exceptions::RecordNotFoundError;
use rust_decimal::Decimal;
use serde_json::json;
use std::str::FromStr;

struct TestHarness {
    crop_gw: CropGw,
    template_gw: TemplateGw,
    blueprint_gw: BlueprintGw,
    req_gw: ReqGw,
    schedule_gw: ScheduleGw,
    fertilize_gw: FertilizeGw,
}

impl TestHarness {
    fn interactor(&self) -> CropRegenerateTaskScheduleBlueprintsInteractor<'_, CropGw, TemplateGw, BlueprintGw, ReqGw, ScheduleGw, FertilizeGw> {
        CropRegenerateTaskScheduleBlueprintsInteractor::new(
            &self.crop_gw,
            &self.template_gw,
            &self.blueprint_gw,
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
    fn masters_crop_agricultural_task_templates_index_rows(
        &self,
        _: i64,
    ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
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
        Err("unsupported".into())
    }
    fn delete_masters_crop_task_template(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
}

struct TemplateGw {
    templates: Vec<CropTaskTemplateEntity>,
}

impl CropMastersTaskTemplateGateway for TemplateGw {
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
        Err("unsupported".into())
    }
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.templates.clone())
    }
}

struct BlueprintGw;

impl CropMastersTaskScheduleBlueprintGateway for BlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<crate::crop::dtos::MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn create(
        &self,
        _: crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<crate::crop::dtos::MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        Err("unsupported".into())
    }
    fn update(
        &self,
        _: i64,
        _: i64,
        _: serde_json::Value,
    ) -> Result<crate::crop::dtos::MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
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
    ) -> Result<Vec<crate::crop::dtos::MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
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

fn sample_template() -> CropTaskTemplateEntity {
    CropTaskTemplateEntity {
        id: 10,
        crop_id: 1,
        agricultural_task_id: 100,
        name: "除草".into(),
        description: None,
        time_per_sqm: Some(Decimal::from_str("1.0").unwrap()),
        weather_dependency: None,
        required_tools: vec![],
        skill_level: None,
        created_at: None,
        updated_at: None,
    }
}

#[test]
fn regenerate_fails_when_templates_empty() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        template_gw: TemplateGw { templates: vec![] },
        blueprint_gw: BlueprintGw,
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
        CropBlueprintRegenerateFailureReason::MissingTaskTemplates
    );
}

#[test]
fn regenerate_succeeds_with_stub_ai_responses() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        template_gw: TemplateGw {
            templates: vec![sample_template()],
        },
        blueprint_gw: BlueprintGw,
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
    assert!(rows.is_empty());
}

#[test]
fn regenerate_maps_daemon_unavailable_to_ai_unavailable() {
    let harness = TestHarness {
        crop_gw: CropGw {
            crop: Some(sample_crop()),
        },
        template_gw: TemplateGw {
            templates: vec![sample_template()],
        },
        blueprint_gw: BlueprintGw,
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
