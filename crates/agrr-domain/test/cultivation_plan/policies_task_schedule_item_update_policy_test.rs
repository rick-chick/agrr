// Tests for `policies/task_schedule_item_update_policy.rs` (Ruby parity under test/domain/cultivation_plan/).

    use rust_decimal::Decimal;
    use time::macros::{date, datetime};

    fn amount_snapshot(scheduled_date: Date) -> TaskScheduleItemAmountSnapshot {
        TaskScheduleItemAmountSnapshot {
            amount: Some(Decimal::ONE),
            amount_unit: Some("kg/ha".into()),
            scheduled_date,
        }
    }

    // Ruby: test "build_update_attributes sets rescheduled when scheduled_date changes"
    #[test]
    fn build_update_attributes_sets_rescheduled_when_scheduled_date_changes() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("scheduled_date".into(), "2026-06-15".into());
        seed.insert("name".into(), "作業".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("scheduled_date").map(String::as_str), Some("2026-06-15"));
        assert_eq!(result.get("name").map(String::as_str), Some("作業"));
        assert!(result.contains_key("rescheduled_at"));
        assert_eq!(result.get("status").map(String::as_str), Some(RESCHEDULED));
    }

    // Ruby: test "build_update_attributes does not reschedule when scheduled_date unchanged"
    #[test]
    fn build_update_attributes_does_not_reschedule_when_scheduled_date_unchanged() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("scheduled_date".into(), "2026-05-01".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("scheduled_date").map(String::as_str), Some("2026-05-01"));
        assert!(!result.contains_key("rescheduled_at"));
        assert!(!result.contains_key("status"));
    }

    // Ruby: test "build_update_attributes applies calculator unit conversion"
    #[test]
    fn build_update_attributes_applies_calculator_unit_conversion() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("amount_unit".into(), "g/m2".into());
        seed.insert("amount".into(), "1.0".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        let amount: f64 = result["amount"].parse().unwrap();
        assert!((amount - 0.1).abs() < 0.0001);
        assert_eq!(result.get("amount_unit").map(String::as_str), Some("g/m2"));
    }

    // Ruby: test "build_update_attributes omits reschedule when scheduled_date blank"
    #[test]
    fn build_update_attributes_omits_reschedule_when_scheduled_date_blank() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("name".into(), "作業のみ".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("name").map(String::as_str), Some("作業のみ"));
        assert!(!result.contains_key("rescheduled_at"));
        assert!(!result.contains_key("status"));
    }
