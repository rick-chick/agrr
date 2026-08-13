//! Plan vs actual read models for schedule items and plan-level summary.

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVsActualItemRead {
    pub item_id: i64,
    pub field_cultivation_id: i64,
    pub category: String,
    pub name: String,
    pub scheduled_date: Option<String>,
    pub actual_date: Option<String>,
    pub delta_days: Option<i64>,
    pub gdd_trigger: Option<f64>,
    pub gdd_at_actual: Option<f64>,
    pub gdd_delta: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVsActualCategorySummaryRead {
    pub category: String,
    pub average_delta_days: Option<f64>,
    pub item_count: i64,
    pub recorded_count: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct StageGddCalibrationProposalRead {
    pub crop_id: i64,
    pub crop_name: String,
    pub stage_order: i32,
    pub stage_name: String,
    pub average_gdd_delta: f64,
    pub recorded_item_count: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVsActualSummaryRead {
    pub plan_id: i64,
    pub unrecorded_count: i64,
    pub categories: Vec<PlanVsActualCategorySummaryRead>,
    pub top_variance_items: Vec<PlanVsActualItemRead>,
    pub stage_gdd_calibration_proposals: Vec<StageGddCalibrationProposalRead>,
}
