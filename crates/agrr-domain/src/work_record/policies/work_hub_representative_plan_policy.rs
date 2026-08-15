//! Representative private cultivation plan selection for work hub (`GET /api/v1/work/hub`).
//!
//! Per farm, pick one `plan_type = 'private'` plan owned by the user:
//! 1. Latest **active** plan (`status = 'completed'`) by `updated_at`, then `id`.
//! 2. If none, latest **draft** plan (`status = 'pending'`) by the same ordering.
//! 3. `optimizing` / `failed` / other statuses are not representative.

pub const ACTIVE_PLAN_STATUS: &str = "completed";
pub const DRAFT_PLAN_STATUS: &str = "pending";

/// SQLite `ORDER BY` rank for representative plan subqueries (lower = preferred).
pub fn representative_plan_status_rank(status: &str) -> Option<i32> {
    match status {
        ACTIVE_PLAN_STATUS => Some(0),
        DRAFT_PLAN_STATUS => Some(1),
        _ => None,
    }
}

pub fn is_representative_plan_status(status: &str) -> bool {
    representative_plan_status_rank(status).is_some()
}

#[cfg(test)]
mod policies_work_hub_representative_plan_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/policies_work_hub_representative_plan_policy_test.rs"
    ));
}
