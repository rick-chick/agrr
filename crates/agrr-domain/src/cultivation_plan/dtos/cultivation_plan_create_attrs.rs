//! Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanCreateAttrs`

use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanCreateAttrs {
    pub farm_id: i64,
    pub user_id: Option<i64>,
    pub total_area: f64,
    pub plan_type: String,
    pub session_id: Option<String>,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub planning_start_date: Option<Date>,
    pub planning_end_date: Option<Date>,
    pub status: Option<String>,
}
