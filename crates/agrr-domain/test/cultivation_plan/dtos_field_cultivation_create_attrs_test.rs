// Tests for `dtos/field_cultivation_create_attrs.rs` (Ruby parity under test/domain/cultivation_plan/).

use serde_json::json;

    use crate::cultivation_plan::dtos::OptimizationApplyAttrs;

    // Ruby: test "to_active_record_attributes nests optimization snapshot"
    #[test]
    fn to_active_record_attributes_nests_optimization_snapshot() {
        let allocation = json!({ "crop_id": "9", "area_used": 10.0 });
        let opt = FieldCultivationOptimizationPersist::new(11, 100.0, 40.0, allocation);
        let dto = FieldCultivationCreateAttrs::new(
            1,
            2,
            10.0,
            Date::from_calendar_date(2024, time::Month::April, 1).unwrap(),
            Date::from_calendar_date(2024, time::Month::June, 1).unwrap(),
            60,
            60.0,
            "completed",
            opt,
        );

        let h = dto.to_active_record_attributes();
        assert_eq!(h.get("cultivation_plan_field_id").and_then(|v| v.as_i64()), Some(1));
        let opt_h = h.get("optimization_result").unwrap().as_object().unwrap();
        let raw = opt_h.get("raw").unwrap().as_object().unwrap();
        assert_eq!(raw.get("crop_id").and_then(|v| v.as_str()), Some("9"));
        assert!(
            (opt_h
                .get("expected_revenue")
                .and_then(|v| v.as_f64())
                .unwrap()
                - 100.0)
                .abs()
                < 0.001
        );
    }

    // Ruby: test "optimization_apply_attrs maps keys for update"
    #[test]
    fn optimization_apply_attrs_maps_keys_for_update() {
        let dto = OptimizationApplyAttrs::new(1.0, 2.0, 3.0, 12.5, "greedy", true, "{}");
        let h = dto.to_active_record_attributes();
        assert!((h.get("total_profit").and_then(|v| v.as_f64()).unwrap() - 1.0).abs() < 0.001);
        assert_eq!(h.get("optimization_summary").and_then(|v| v.as_str()), Some("{}"));
        assert_eq!(h.get("is_optimal").and_then(|v| v.as_bool()), Some(true));
    }
