//! Plan-save farm DTOs (Ruby: `Domain::CultivationPlan::Dtos::*` farm-related).

#[derive(Debug, Clone)]
pub struct PlanSaveReferenceFarmSnapshot {
    pub id: i64,
    pub name: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub region: Option<String>,
    pub weather_location_id: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveUserFarmSnapshot {
    pub id: i64,
    pub name: Option<String>,
    pub region: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserFarmInput {
    pub user_id: i64,
    pub reference_farm_id: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserFarmOutput {
    pub farm_id: i64,
    pub farm_reused: bool,
    pub farm_region: Option<String>,
}
