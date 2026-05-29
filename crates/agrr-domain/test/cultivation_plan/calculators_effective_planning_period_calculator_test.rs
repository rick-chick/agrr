// Tests for `calculators/effective_planning_period_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;

    // Ruby: test "calculate uses allocations and moves to extend range"
    #[test]
    fn calculate_uses_allocations_and_moves_to_extend_range() {
        let current_allocation = json!({
            "optimization_result": {
                "field_schedules": [{
                    "allocations": [{
                        "start_date": "2024-04-01",
                        "completion_date": "2024-06-01",
                        "allocation_id": 11
                    }]
                }]
            }
        });
        let moves = vec![json!({ "to_start_date": "2025-02-10" })];
        let (start_date, end_date) = calculate(
            &current_allocation,
            &moves,
            &[],
            Some(date_ymd(2023, 1, 1)),
            Some(date_ymd(2023, 12, 31)),
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2023, 1, 1));
        assert_eq!(end_date, date_ymd(2026, 12, 31));
    }

    // Ruby: test "calculate uses planning dates or as_of when no periods exist"
    #[test]
    fn calculate_uses_planning_dates_or_as_of_when_no_periods() {
        let (start_date, end_date) = calculate(
            &json!({}),
            &[],
            &[],
            Some(date_ymd(2024, 1, 15)),
            Some(date_ymd(2024, 12, 31)),
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2024, 1, 15));
        assert_eq!(end_date, date_ymd(2024, 12, 31));

        let (start_date, end_date) = calculate(
            &json!({}),
            &[],
            &[],
            None,
            None,
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2025, 5, 6));
        assert_eq!(end_date, date_ymd(2027, 12, 31));
    }

    // Ruby: test "calculate raises error for invalid date"
    #[test]
    fn calculate_raises_error_for_invalid_date() {
        let err = calculate(
            &json!({
                "optimization_result": {
                    "field_schedules": [{
                        "allocations": [{
                            "start_date": "invalid-date",
                            "completion_date": null,
                            "allocation_id": 55
                        }]
                    }]
                }
            }),
            &[],
            &[],
            None,
            None,
            date_ymd(2025, 5, 6),
        )
        .unwrap_err();
        assert_eq!(err.raw_value, "invalid-date");
        assert_eq!(err.field, EffectivePlanningPeriodDateField::StartDate);
        assert_eq!(err.allocation_id, Some(55));
    }
