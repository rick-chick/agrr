//! Plan-save fertilize DTOs.

#[derive(Debug, Clone)]
pub struct PublicPlanSaveFertilizeReferenceRow {
    pub reference_fertilize_id: i64,
    pub name: Option<String>,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub region: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveUserFertilizeSnapshot {
    pub id: i64,
    pub name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserFertilizesInput {
    pub user_id: i64,
    pub region: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserFertilizesOutput {
    pub user_fertilize_ids: Vec<i64>,
    pub skipped_fertilize_ids: Vec<i64>,
}
