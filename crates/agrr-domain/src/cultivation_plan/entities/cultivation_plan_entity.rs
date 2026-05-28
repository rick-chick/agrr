//! Ruby: `Domain::CultivationPlan::Entities::CultivationPlanEntity`

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanEntity {
    pub id: i64,
    pub farm_id: i64,
    pub user_id: i64,
    pub total_area: f64,
    pub plan_type: String,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub planning_start_date: Option<String>,
    pub planning_end_date: Option<String>,
    pub status: Option<String>,
    pub session_id: Option<String>,
    pub display_name: Option<String>,
    pub optimization_phase: Option<String>,
    pub optimization_phase_message: Option<String>,
    pub cultivation_plan_crops_count: i32,
    pub cultivation_plan_fields_count: i32,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl CultivationPlanEntity {
    pub fn plan_type_private(&self) -> bool {
        self.plan_type == "private"
    }
}
