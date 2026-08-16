//! Plan vs actual read models for schedule items and plan-level summary.

use crate::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;

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
    pub amount_planned: Option<f64>,
    pub amount_actual: Option<f64>,
    pub amount_delta: Option<f64>,
    pub amount_unit: Option<String>,
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
pub struct PlanVarianceActionItemRead {
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
    pub amount_planned: Option<f64>,
    pub amount_actual: Option<f64>,
    pub amount_delta: Option<f64>,
    pub amount_unit: Option<String>,
    pub exceedance_kind: VarianceExceedanceKind,
}

impl PlanVarianceActionItemRead {
    pub fn from_item(item: &PlanVsActualItemRead, exceedance_kind: VarianceExceedanceKind) -> Self {
        Self {
            item_id: item.item_id,
            field_cultivation_id: item.field_cultivation_id,
            category: item.category.clone(),
            name: item.name.clone(),
            scheduled_date: item.scheduled_date.clone(),
            actual_date: item.actual_date.clone(),
            delta_days: item.delta_days,
            gdd_trigger: item.gdd_trigger,
            gdd_at_actual: item.gdd_at_actual,
            gdd_delta: item.gdd_delta,
            amount_planned: item.amount_planned,
            amount_actual: item.amount_actual,
            amount_delta: item.amount_delta,
            amount_unit: item.amount_unit.clone(),
            exceedance_kind,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct BlueprintTimingAdjustmentProposalRead {
    pub crop_id: i64,
    pub crop_name: String,
    pub category: String,
    pub average_delta_days: f64,
    pub average_gdd_delta: Option<f64>,
    pub recorded_item_count: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVsActualAmountDeltaSummaryRead {
    pub category: String,
    pub stage_order: Option<i32>,
    pub stage_name: Option<String>,
    pub task_type: String,
    pub average_amount_delta: f64,
    pub recorded_item_count: i64,
    pub amount_unit: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVsActualSummaryRead {
    pub plan_id: i64,
    pub unrecorded_count: i64,
    pub structured_unrecorded_count: i64,
    pub categories: Vec<PlanVsActualCategorySummaryRead>,
    pub top_variance_items: Vec<PlanVsActualItemRead>,
    pub stage_gdd_calibration_proposals: Vec<StageGddCalibrationProposalRead>,
    pub action_required_items: Vec<PlanVarianceActionItemRead>,
    pub blueprint_timing_adjustment_proposals: Vec<BlueprintTimingAdjustmentProposalRead>,
    pub amount_delta_summaries: Vec<PlanVsActualAmountDeltaSummaryRead>,
}
