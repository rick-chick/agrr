//! Which proposal application progress statuses qualify for optimize-time learn delta injection.

pub fn qualifies_for_optimize_injection(status: &str) -> bool {
    matches!(status, "confirmed" | "done")
}

#[cfg(test)]
mod policies_optimization_learn_applied_proposal_policy_test_inline {
    use super::*;

    #[test]
    fn confirmed_and_done_qualify_for_injection() {
        assert!(qualifies_for_optimize_injection("confirmed"));
        assert!(qualifies_for_optimize_injection("done"));
    }

    #[test]
    fn other_statuses_do_not_qualify() {
        for status in [
            "not_started",
            "applied_pending_confirmation",
            "dismissed",
            "invalid",
        ] {
            assert!(
                !qualifies_for_optimize_injection(status),
                "expected {status} to be excluded"
            );
        }
    }
}
