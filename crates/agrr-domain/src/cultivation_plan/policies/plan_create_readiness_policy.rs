//! Readiness checks for private plan creation from farm selection.

use rust_decimal::Decimal;

use crate::crop::entities::CropStageEntity;
use crate::cultivation_plan::dtos::crop_task_schedule_blueprint::CropTaskScheduleBlueprintRow;

const FIELD_WORK_TASK_TYPE: &str = "field_work";
const BASAL_FERTILIZATION_TASK_TYPE: &str = "basal_fertilization";
const TOPDRESS_FERTILIZATION_TASK_TYPE: &str = "topdress_fertilization";

pub fn weather_ready(status: Option<&str>) -> bool {
    status == Some("completed")
}

pub fn stage_requirements_complete(stage: &CropStageEntity) -> bool {
    let base_temperature = stage
        .temperature_requirement
        .as_ref()
        .and_then(|req| req.base_temperature);
    let required_gdd = stage
        .thermal_requirement
        .as_ref()
        .and_then(|req| req.required_gdd);
    match (base_temperature, required_gdd) {
        (Some(base), Some(gdd)) => gdd > Decimal::ZERO && base.is_sign_positive(),
        _ => false,
    }
}

pub fn stage_requirements_ready(stages: &[CropStageEntity]) -> bool {
    !stages.is_empty() && stages.iter().all(stage_requirements_complete)
}

pub fn blueprint_generation_ready(
    stages: &[CropStageEntity],
    blueprints: &[CropTaskScheduleBlueprintRow],
) -> bool {
    let has_field_work = blueprints
        .iter()
        .any(|bp| bp.task_type == FIELD_WORK_TASK_TYPE);
    let has_fertilizer = blueprints.iter().any(|bp| {
        bp.task_type == BASAL_FERTILIZATION_TASK_TYPE
            || bp.task_type == TOPDRESS_FERTILIZATION_TASK_TYPE
    });
    let field_work_blueprints_ready = has_field_work || has_fertilizer;
    let fertilizer_blueprints_ready = has_fertilizer;
    let blueprints_ready = field_work_blueprints_ready && fertilizer_blueprints_ready;
    blueprints_ready && stage_requirements_ready(stages)
}

pub fn crops_ready(crop_inputs: &[(Vec<CropStageEntity>, Vec<CropTaskScheduleBlueprintRow>)]) -> bool {
    crop_inputs
        .iter()
        .any(|(stages, blueprints)| blueprint_generation_ready(stages, blueprints))
}

#[cfg(test)]
mod plan_create_readiness_policy_test {
    use super::*;
    use crate::crop::entities::{
        CropStageEntity, TemperatureRequirementEntity, ThermalRequirementEntity,
    };

    fn stage_with_requirements(required_gdd: Decimal) -> CropStageEntity {
        CropStageEntity {
            id: 1,
            crop_id: 1,
            name: "Vegetative".into(),
            order: 1,
            temperature_requirement: Some(TemperatureRequirementEntity {
                id: 1,
                crop_stage_id: 1,
                base_temperature: Some(Decimal::from(10)),
                optimal_min: None,
                optimal_max: None,
                low_stress_threshold: None,
                high_stress_threshold: None,
                frost_threshold: None,
                sterility_risk_threshold: None,
                max_temperature: None,
            }),
            thermal_requirement: Some(ThermalRequirementEntity {
                id: 1,
                crop_stage_id: 1,
                required_gdd: Some(required_gdd),
            }),
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: None,
            updated_at: None,
        }
    }

    fn blueprint(task_type: &str) -> CropTaskScheduleBlueprintRow {
        CropTaskScheduleBlueprintRow {
            agricultural_task_id: Some(1),
            source_agricultural_task_id: None,
            stage_order: 1,
            stage_name: "Vegetative".into(),
            gdd_trigger: Some(Decimal::from(100)),
            gdd_tolerance: None,
            task_type: task_type.into(),
            source: "manual".into(),
            priority: 1,
            amount: None,
            amount_unit: None,
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
        }
    }

    #[test]
    fn weather_ready_is_true_only_for_completed() {
        assert!(weather_ready(Some("completed")));
        assert!(!weather_ready(Some("pending")));
        assert!(!weather_ready(Some("fetching")));
        assert!(!weather_ready(Some("failed")));
        assert!(!weather_ready(None));
    }

    #[test]
    fn crops_ready_requires_field_work_and_fertilizer_blueprints_and_stage_requirements() {
        let stages = vec![stage_with_requirements(Decimal::from(100))];
        let ready_blueprints = vec![
            blueprint(FIELD_WORK_TASK_TYPE),
            blueprint(BASAL_FERTILIZATION_TASK_TYPE),
        ];
        assert!(crops_ready(&[(stages.clone(), ready_blueprints.clone())]));

        let only_field_work = vec![blueprint(FIELD_WORK_TASK_TYPE)];
        assert!(!crops_ready(&[(stages.clone(), only_field_work)]));

        let mut incomplete_stage = stage_with_requirements(Decimal::ZERO);
        incomplete_stage.thermal_requirement = None;
        assert!(!crops_ready(&[(vec![incomplete_stage], ready_blueprints)]));
    }
}
