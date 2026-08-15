use super::{
    ACTIVE_PLAN_STATUS, DRAFT_PLAN_STATUS, is_representative_plan_status,
    representative_plan_status_rank,
};

#[test]
fn active_completed_plan_outranks_draft_pending() {
    assert_eq!(Some(0), representative_plan_status_rank(ACTIVE_PLAN_STATUS));
    assert_eq!(Some(1), representative_plan_status_rank(DRAFT_PLAN_STATUS));
    assert!(representative_plan_status_rank("optimizing").is_none());
    assert!(representative_plan_status_rank("failed").is_none());
}

#[test]
fn representative_statuses_are_completed_and_pending_only() {
    assert!(is_representative_plan_status(ACTIVE_PLAN_STATUS));
    assert!(is_representative_plan_status(DRAFT_PLAN_STATUS));
    assert!(!is_representative_plan_status("optimizing"));
    assert!(!is_representative_plan_status("failed"));
}
