// Tests for `policies/cultivation_plan_optimization_complete_policy.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "should_mark_plan_completed when optimizing and all field cultivations completed"
    #[test]
    fn should_mark_plan_completed_when_optimizing_and_all_completed() {
        assert!(should_mark_plan_completed(
            "optimizing",
            &["completed".into(), "completed".into()]
        ));
    }

    // Ruby: test "should not mark when not optimizing"
    #[test]
    fn should_not_mark_when_not_optimizing() {
        assert!(!should_mark_plan_completed("completed", &["completed".into()]));
    }

    // Ruby: test "should not mark when field cultivations empty"
    #[test]
    fn should_not_mark_when_field_cultivations_empty() {
        assert!(!should_mark_plan_completed("optimizing", &[]));
    }
