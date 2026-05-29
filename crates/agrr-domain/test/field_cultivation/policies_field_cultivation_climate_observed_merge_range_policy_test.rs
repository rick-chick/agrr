// Tests for `policies/field_cultivation_climate_observed_merge_range_policy.rs` (Ruby parity under test/domain/field_cultivation/).

    use time::macros::date;

    #[test]
    fn caps_observed_end_at_today_minus_one() {
        let decision = resolve_observed_merge_range(
            None,
            None,
            Some(date!(2026 - 01 - 01)),
            Some(date!(2026 - 12 - 31)),
            date!(2026 - 03 - 10),
        );
        assert!(!decision.skip_merge());
        assert_eq!(decision.start_date, Some(date!(2026 - 01 - 01)));
        assert_eq!(decision.end_date, Some(date!(2026 - 03 - 09)));
    }

    #[test]
    fn skips_when_start_after_actual_end() {
        let decision = resolve_observed_merge_range(
            Some("2026-05-01"),
            Some("2026-06-01"),
            Some(date!(2026 - 01 - 01)),
            Some(date!(2026 - 12 - 31)),
            date!(2026 - 03 - 01),
        );
        assert!(decision.skip_merge());
    }
