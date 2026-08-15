//! Aggregates plan-vs-actual summary into portfolio row counters.

use crate::cultivation_plan::dtos::plan_vs_actual::{
    PlanVarianceActionItemRead, PlanVsActualSummaryRead,
};
use crate::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlanVarianceSummaryStats {
    pub unrecorded_count: i64,
    pub threshold_exceeded_count: i64,
    pub gdd_delay_count: i64,
    pub days_threshold_exceeded_count: i64,
}

pub const EMPTY_PLAN_VARIANCE_SUMMARY_STATS: PlanVarianceSummaryStats = PlanVarianceSummaryStats {
    unrecorded_count: 0,
    threshold_exceeded_count: 0,
    gdd_delay_count: 0,
    days_threshold_exceeded_count: 0,
};

pub fn stats_from_summary(summary: &PlanVsActualSummaryRead) -> PlanVarianceSummaryStats {
    let action_items = &summary.action_required_items;
    PlanVarianceSummaryStats {
        unrecorded_count: summary.unrecorded_count,
        threshold_exceeded_count: action_items.len() as i64,
        gdd_delay_count: action_items
            .iter()
            .filter(|item| is_gdd_delay_item(item))
            .count() as i64,
        days_threshold_exceeded_count: action_items
            .iter()
            .filter(|item| is_days_exceedance_item(item))
            .count() as i64,
    }
}

fn is_days_exceedance_item(item: &PlanVarianceActionItemRead) -> bool {
    matches!(
        item.exceedance_kind,
        VarianceExceedanceKind::Days | VarianceExceedanceKind::Both
    )
}

fn is_gdd_delay_item(item: &PlanVarianceActionItemRead) -> bool {
    matches!(
        item.exceedance_kind,
        VarianceExceedanceKind::Gdd | VarianceExceedanceKind::Both
    )
}

#[cfg(test)]
mod policies_plan_variance_summary_stats_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_plan_variance_summary_stats_policy_test.rs"
    ));
}
