// Tests for `policies/variance_portfolio_carryover_policy.rs`.

use crate::cultivation_plan::dtos::PrivatePlanIndexPlanRow;
use crate::work_record::policies::variance_portfolio_carryover_policy::carryover_not_imported;

fn plan_row(id: i64, farm_id: i64, status: &str) -> PrivatePlanIndexPlanRow {
    PrivatePlanIndexPlanRow {
        id,
        farm_id,
        farm_display_name: format!("Farm {farm_id}"),
        total_area: 10.0,
        crops_count: 1,
        fields_count: 1,
        status: status.into(),
        display_name: format!("Plan {id}"),
        created_at: "2026-01-01".into(),
        plan_year: Some(2026),
    }
}

#[test]
fn true_when_pending_plan_has_completed_source_without_snapshot() {
    let completed = plan_row(1, 5, "completed");
    let pending = plan_row(2, 5, "pending");
    assert!(carryover_not_imported(&pending, &[completed, pending.clone()], false));
}

#[test]
fn false_when_learning_snapshot_exists() {
    let completed = plan_row(1, 5, "completed");
    let pending = plan_row(2, 5, "pending");
    let plans = vec![completed, pending.clone()];
    assert!(!carryover_not_imported(&pending, &plans, true));
}

#[test]
fn false_when_no_completed_source_on_same_farm() {
    let pending = plan_row(2, 5, "pending");
    assert!(!carryover_not_imported(&pending, &[pending.clone()], false));
}
