// Tests for `calculators/agrr_fields_config_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "build maps fields and defaults daily_fixed_cost"
    #[test]
    fn build_maps_fields_and_defaults_daily_fixed_cost() {
        let plan_fields = vec![AgrrPlanFieldRow {
            id: "10".into(),
            name: "Field A".into(),
            area: 1.25,
            daily_fixed_cost: None,
        }];
        let result = build(&plan_fields);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["field_id"], "10");
        assert_eq!(result[0]["name"], "Field A");
        assert_eq!(result[0]["area"], 1.25);
        assert_eq!(result[0]["daily_fixed_cost"], 0.0);
    }
