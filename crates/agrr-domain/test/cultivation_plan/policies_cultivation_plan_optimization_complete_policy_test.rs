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

    #[test]
    fn allocation_has_field_schedules_when_non_empty() {
        let v = serde_json::json!({ "field_schedules": [{ "field_id": 1 }] });
        assert!(allocation_has_field_schedules(&v));
    }

    #[test]
    fn allocation_has_field_schedules_false_when_empty_or_missing() {
        assert!(!allocation_has_field_schedules(&serde_json::json!({ "field_schedules": [] })));
        assert!(!allocation_has_field_schedules(&serde_json::json!({})));
    }
