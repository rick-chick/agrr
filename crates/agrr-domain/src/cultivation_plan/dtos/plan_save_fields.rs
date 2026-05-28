//! Plan-save field DTOs.

use super::PublicPlanSaveFieldDatum;

#[derive(Debug, Clone)]
pub struct PlanSaveFieldSnapshot {
    pub id: i64,
    pub name: Option<String>,
    pub area: Option<f64>,
    pub farm_id: i64,
    pub user_id: i64,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserFieldsInput {
    pub user_id: i64,
    pub farm_id: i64,
    pub farm_reused: bool,
    pub field_data: Vec<PublicPlanSaveFieldDatum>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserFieldsOutput {
    pub field_ids: Vec<i64>,
    pub skipped_field_ids: Vec<i64>,
}
