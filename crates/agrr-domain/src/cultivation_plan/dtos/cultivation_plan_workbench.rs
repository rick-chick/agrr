//! Workbench read DTOs for retrieve interactor.

use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanWorkbenchPlanHeader {
    pub id: i64,
    pub user_id: Option<i64>,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub plan_type: String,
    pub status: String,
    pub total_area: f64,
    pub planning_start_date: Option<String>,
    pub planning_end_date: Option<String>,
    pub total_profit: f64,
    pub total_revenue: f64,
    pub total_cost: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanWorkbenchSnapshot {
    pub plan: CultivationPlanWorkbenchPlanHeader,
    pub fields: Vec<Value>,
    pub crops: Vec<Value>,
    pub cultivations: Vec<Value>,
    pub available_crop_rows: Vec<Value>,
    pub farm_region: String,
}
