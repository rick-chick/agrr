// Tests for `policies/field_cultivation_climate_fallback_horizon_policy.rs` (Ruby parity under test/domain/field_cultivation/).

    use time::macros::date;

    #[test]
    fn prediction_days_is_inclusive_day_delta() {
        let completion = date!(2026 - 06 - 01);
        let training_end = date!(2026 - 01 - 01);
        assert_eq!(prediction_days(completion, training_end), 151);
    }

    #[test]
    fn use_prediction_branch_when_positive() {
        assert!(use_prediction_branch(1));
        assert!(!use_prediction_branch(0));
        assert!(!use_prediction_branch(-1));
    }
