//! REST plan read snapshots (per-table; composed in domain mappers).

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanRestPlanHeaderSnapshot {
    pub id: i64,
    pub user_id: Option<i64>,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub display_name: String,
    pub plan_type: String,
    pub status: String,
    pub total_area: f64,
    pub planning_start_date: Option<String>,
    pub planning_end_date: Option<String>,
    pub calculated_planning_start_date: Option<String>,
    pub prediction_target_end_date: Option<String>,
    pub total_profit: f64,
    pub total_revenue: f64,
    pub total_cost: f64,
    pub farm_display_name: String,
    pub farm_region: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanRestPlanFieldRowSnapshot {
    pub id: i64,
    pub display_name: String,
    pub area: f64,
    pub daily_fixed_cost: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanRestPlanCropRowSnapshot {
    pub id: i64,
    pub display_name: String,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanRestPlanCultivationRowSnapshot {
    pub id: i64,
    pub cultivation_plan_field_id: Option<i64>,
    pub field_display_name: String,
    pub cultivation_plan_crop_id: Option<i64>,
    pub crop_display_name: String,
    pub area: f64,
    pub start_date: Option<String>,
    pub completion_date: Option<String>,
    pub cultivation_days: Option<i32>,
    pub estimated_cost: Option<f64>,
    pub optimization_result: Option<String>,
    pub status: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanRestPlanSnapshot {
    pub id: i64,
    pub user_id: Option<i64>,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub display_name: String,
    pub plan_type: String,
    pub status: String,
    pub total_area: f64,
    pub planning_start_date: Option<String>,
    pub planning_end_date: Option<String>,
    pub calculated_planning_start_date: Option<String>,
    pub prediction_target_end_date: Option<String>,
    pub total_profit: f64,
    pub total_revenue: f64,
    pub total_cost: f64,
    pub farm_display_name: String,
    pub farm_region: String,
    pub field_rows: Vec<CultivationPlanRestPlanFieldRowSnapshot>,
    pub crop_rows: Vec<CultivationPlanRestPlanCropRowSnapshot>,
    pub cultivation_rows: Vec<CultivationPlanRestPlanCultivationRowSnapshot>,
    pub palette_crop_ids: Vec<i64>,
}
