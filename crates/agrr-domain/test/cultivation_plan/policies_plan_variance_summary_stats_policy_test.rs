// Tests for `policies/plan_variance_summary_stats_policy.rs`.

use crate::cultivation_plan::dtos::plan_vs_actual::PlanVsActualSummaryRead;
use crate::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;

fn action_item(exceedance_kind: VarianceExceedanceKind) -> PlanVarianceActionItemRead {
    PlanVarianceActionItemRead {
        item_id: 1,
        field_cultivation_id: 2,
        category: "general".into(),
        name: "task".into(),
        scheduled_date: Some("2026-06-01".into()),
        actual_date: Some("2026-06-10".into()),
        delta_days: Some(9),
        gdd_trigger: Some(100.0),
        gdd_at_actual: Some(110.0),
        gdd_delta: Some(10.0),
        exceedance_kind,
    }
}

#[test]
fn counts_unrecorded_and_threshold_items() {
    let summary = PlanVsActualSummaryRead {
        plan_id: 7,
        unrecorded_count: 3,
        structured_unrecorded_count: 0,
        categories: vec![],
        amount_group_summaries: vec![],
        top_variance_items: vec![],
        stage_gdd_calibration_proposals: vec![],
        action_required_items: vec![
            action_item(VarianceExceedanceKind::Days),
            action_item(VarianceExceedanceKind::Gdd),
            action_item(VarianceExceedanceKind::Both),
        ],
        blueprint_timing_adjustment_proposals: vec![],
    };

    let stats = stats_from_summary(&summary);
    assert_eq!(3, stats.unrecorded_count);
    assert_eq!(3, stats.threshold_exceeded_count);
    assert_eq!(2, stats.gdd_delay_count);
    assert_eq!(2, stats.days_threshold_exceeded_count);
}
