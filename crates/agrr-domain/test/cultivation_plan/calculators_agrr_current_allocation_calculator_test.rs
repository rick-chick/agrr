// Tests for `calculators/agrr_current_allocation_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).

    use time::Month;

    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), day).unwrap()
    }

    // Ruby: test "build aggregates optimization_result from field rows"
    #[test]
    fn build_aggregates_optimization_result_from_field_rows() {
        let field_rows = vec![
            AgrrFieldRow {
                field_id: 1,
                field_name: "North".into(),
                field_area: 100.0,
                allocations: vec![AgrrAllocationRow {
                    allocation_id: 10,
                    crop_id: "5".into(),
                    crop_name: "Tomato".into(),
                    variety: Some("A".into()),
                    area_used: 40.0,
                    start_date: Some(d(2025, 4, 1)),
                    completion_date: Some(d(2025, 7, 1)),
                    growth_days: 92,
                    accumulated_gdd: 1.5,
                    total_cost: 100.0,
                    expected_revenue: 300.0,
                }],
            },
            AgrrFieldRow {
                field_id: 2,
                field_name: "South".into(),
                field_area: 50.0,
                allocations: vec![],
            },
        ];

        let result = build(42, &field_rows);
        let opt = &result["optimization_result"];
        assert_eq!(opt["optimization_id"], "opt_42");
        assert!((opt["total_cost"].as_f64().unwrap() - 100.0).abs() < 0.001);
        assert!((opt["total_revenue"].as_f64().unwrap() - 300.0).abs() < 0.001);
        assert!((opt["total_profit"].as_f64().unwrap() - 200.0).abs() < 0.001);

        let schedules = opt["field_schedules"].as_array().unwrap();
        assert_eq!(schedules.len(), 2);

        let first = &schedules[0];
        assert_eq!(first["field_id"], "1");
        assert_eq!(first["field_name"], "North");
        assert!((first["utilization_rate"].as_f64().unwrap() - 0.4).abs() < 0.001);
        let alloc = &first["allocations"][0];
        assert_eq!(alloc["allocation_id"], 10);
        assert_eq!(alloc["crop_id"], "5");
        assert_eq!(alloc["start_date"], "2025-04-01");
        assert_eq!(alloc["completion_date"], "2025-07-01");
        assert!((alloc["profit"].as_f64().unwrap() - 200.0).abs() < 0.001);

        let last = &schedules[1];
        assert!(last["allocations"].as_array().unwrap().is_empty());
        assert!((last["utilization_rate"].as_f64().unwrap()).abs() < 0.001);
    }
