//! Plan-save agricultural task DTOs.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct PublicPlanSaveCropTaskTemplateLinkRow {
    pub reference_crop_id: i64,
    pub name: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
    pub task_type: Option<String>,
    pub task_type_id: Option<i64>,
    pub is_reference: bool,
}

#[derive(Debug, Clone)]
pub struct PublicPlanSaveAgriculturalTaskReferenceRow {
    pub reference_agricultural_task_id: i64,
    pub name: Option<String>,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
    pub task_type: Option<String>,
    pub task_type_id: Option<i64>,
    pub region: Option<String>,
    pub linked_reference_crop_ids: Vec<i64>,
    pub template_links: Vec<PublicPlanSaveCropTaskTemplateLinkRow>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveUserAgriculturalTaskSnapshot {
    pub id: i64,
    pub name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveCropTaskTemplateLinkSnapshot {
    pub id: i64,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserAgriculturalTasksInput {
    pub user_id: i64,
    pub region: Option<String>,
    pub reference_crop_id_to_user_crop_id: HashMap<i64, i64>,
}

impl PlanSaveEnsureUserAgriculturalTasksInput {
    pub fn reference_crop_ids(&self) -> Vec<i64> {
        self.reference_crop_id_to_user_crop_id
            .keys()
            .copied()
            .collect()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserAgriculturalTasksOutput {
    pub user_agricultural_task_ids: Vec<i64>,
    pub skipped_agricultural_task_ids: Vec<i64>,
    pub reference_agricultural_task_id_to_user_task_id: HashMap<i64, i64>,
}
