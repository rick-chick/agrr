// Tests for `policies/crop_destroy_policy.rs` (Ruby parity under test/domain/crop/).


    // Ruby: test "blocked_reason returns cultivation_plan when cultivation_plan_crops_count positive"
    #[test]
    fn blocked_by_cultivation_plan() {
        let usage = CropDeleteUsage::new(1, 0, 0);
        assert_eq!(
            blocked_reason(&usage),
            Some(CropDestroyBlockedReason::CultivationPlan)
        );
    }

    // Ruby: test "blocked_reason returns other when free crop plans or pesticides in use"
    #[test]
    fn blocked_by_other_usage() {
        let usage = CropDeleteUsage::new(0, 2, 0);
        assert_eq!(blocked_reason(&usage), Some(CropDestroyBlockedReason::Other));
        let usage2 = CropDeleteUsage::new(0, 0, 1);
        assert_eq!(blocked_reason(&usage2), Some(CropDestroyBlockedReason::Other));
    }

    // Ruby: test "blocked_reason returns nil when no usage"
    #[test]
    fn not_blocked_when_no_usage() {
        let usage = CropDeleteUsage::new(0, 0, 0);
        assert_eq!(blocked_reason(&usage), None);
    }
