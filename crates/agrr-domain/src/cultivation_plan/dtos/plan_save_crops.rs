//! Plan-save crop DTOs.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct PublicPlanSaveCropReferenceRow {
    pub cultivation_plan_crop_id: i64,
    pub reference_crop_id: i64,
    pub name: Option<String>,
    pub variety: Option<String>,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
    pub groups: Option<Vec<String>>,
    pub region: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveUserCropSnapshot {
    pub id: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanSaveCropStageCopyPair {
    pub reference_crop_id: i64,
    pub new_crop_id: i64,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserCropsInput {
    pub user_id: i64,
    pub plan_id: i64,
    pub region: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserCropsOutput {
    pub user_crop_ids: Vec<i64>,
    pub skipped_crop_ids: Vec<i64>,
    pub reference_crop_id_to_user_crop_id: HashMap<i64, i64>,
    pub ref_cpc_id_to_user_crop_id: HashMap<i64, i64>,
    pub stage_copy_pairs: Vec<PlanSaveCropStageCopyPair>,
    pub reference_crop_groups: Vec<String>,
}
