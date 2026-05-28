//! Plan-save pest DTOs.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct PublicPlanSavePestTemperatureProfileRow {
    pub base_temperature: Option<f64>,
    pub max_temperature: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct PublicPlanSavePestThermalRequirementRow {
    pub required_gdd: Option<f64>,
    pub first_generation_gdd: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct PublicPlanSavePestControlMethodRow {
    pub method_type: Option<String>,
    pub method_name: Option<String>,
    pub description: Option<String>,
    pub timing_hint: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PublicPlanSavePestReferenceRow {
    pub reference_pest_id: i64,
    pub name: Option<String>,
    pub name_scientific: Option<String>,
    pub family: Option<String>,
    pub order: Option<String>,
    pub description: Option<String>,
    pub occurrence_season: Option<String>,
    pub region: Option<String>,
    pub linked_reference_crop_ids: Vec<i64>,
    pub temperature_profile: Option<PublicPlanSavePestTemperatureProfileRow>,
    pub thermal_requirement: Option<PublicPlanSavePestThermalRequirementRow>,
    pub control_methods: Vec<PublicPlanSavePestControlMethodRow>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveUserPestSnapshot {
    pub id: i64,
    pub name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserPestsInput {
    pub user_id: i64,
    pub plan_id: i64,
    pub region: Option<String>,
    pub reference_crop_id_to_user_crop_id: HashMap<i64, i64>,
}

impl PlanSaveEnsureUserPestsInput {
    pub fn reference_crop_ids(&self) -> Vec<i64> {
        self.reference_crop_id_to_user_crop_id
            .keys()
            .copied()
            .collect()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserPestsOutput {
    pub user_pest_ids: Vec<i64>,
    pub skipped_pest_ids: Vec<i64>,
    pub reference_pest_id_to_user_pest_id: HashMap<i64, i64>,
}
