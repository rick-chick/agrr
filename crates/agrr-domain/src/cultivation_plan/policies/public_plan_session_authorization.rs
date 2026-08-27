//! Public plan mutation requires matching client session from plan creation.

pub fn session_matches(plan_session_id: Option<&str>, requested_session_id: &str) -> bool {
    if requested_session_id.is_empty() {
        return false;
    }
    plan_session_id == Some(requested_session_id)
}

#[cfg(test)]
mod policies_public_plan_session_authorization_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_public_plan_session_authorization_test.rs"
    ));
}
