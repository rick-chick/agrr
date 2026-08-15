//! Carryover-not-imported flag for variance portfolio rows.

use crate::cultivation_plan::dtos::PrivatePlanIndexPlanRow;
use crate::work_record::policies::work_hub_representative_plan_policy::{
    ACTIVE_PLAN_STATUS, DRAFT_PLAN_STATUS,
};

pub fn carryover_not_imported(
    plan: &PrivatePlanIndexPlanRow,
    all_plans: &[PrivatePlanIndexPlanRow],
    has_learning_snapshot: bool,
) -> bool {
    if plan.status != DRAFT_PLAN_STATUS || has_learning_snapshot {
        return false;
    }

    all_plans.iter().any(|other| {
        other.farm_id == plan.farm_id
            && other.id != plan.id
            && other.status == ACTIVE_PLAN_STATUS
    })
}

#[cfg(test)]
mod policies_variance_portfolio_carryover_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/policies_variance_portfolio_carryover_policy_test.rs"
    ));
}
