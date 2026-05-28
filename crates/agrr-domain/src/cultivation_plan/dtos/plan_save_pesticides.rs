//! Plan-save pesticide DTOs.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct PlanSaveUserPesticideSnapshot {
    pub id: i64,
    pub name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserPesticidesInput {
    pub user_id: i64,
    pub region: Option<String>,
    pub reference_crop_id_to_user_crop_id: HashMap<i64, i64>,
    pub reference_pest_id_to_user_pest_id: HashMap<i64, i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserPesticidesOutput {
    pub user_pesticide_ids: Vec<i64>,
    pub skipped_pesticide_ids: Vec<i64>,
}
