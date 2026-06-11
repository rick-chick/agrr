// Tests for `mappers/plan_allocation_adjust_read_snapshot_parts.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;
    use time::macros::date;

    // Ruby: test "build_field_source_snapshots normalizes optimize-style optimization_result keys"
    #[test]
    fn build_field_source_snapshots_normalizes_optimize_style_optimization_result_keys() {
        let plan_field_snapshots = vec![PlanAllocationAdjustPlanFieldSnapshot::new(
            2, "North", 100.0, 5.0,
        )];
        let field_cultivation = PlanAllocationAdjustFieldCultivationSnapshot::new(
            10,
            2,
            5,
            "Tomato",
            None,
            12.0,
            date!(2026-04-01),
            date!(2026-04-20),
            Some(20),
            1,
            Some(100.0),
            Some(json!({
                "expected_revenue": 200.0,
                "profit": 100.0,
                "raw": { "total_gdd": 42.0 }
            })),
        );

        let snapshots = PlanAllocationAdjustReadSnapshotParts::build_field_source_snapshots(
            &plan_field_snapshots,
            &[field_cultivation],
        );
        let source = &snapshots[0].cultivations[0];

        assert!((source.revenue - 200.0).abs() < 0.001);
        assert!((source.accumulated_gdd - 42.0).abs() < 0.001);
        assert_eq!(source.cultivation_days, 20);
        assert!(source.has_growth_stages);
    }

    // Ruby: test "build_field_source_snapshots derives cultivation_days when stored is nil"
    #[test]
    fn build_field_source_snapshots_derives_cultivation_days_when_stored_is_nil() {
        let plan_field_snapshots = vec![PlanAllocationAdjustPlanFieldSnapshot::new(
            1, "A", 10.0, 1.0,
        )];
        let field_cultivation = PlanAllocationAdjustFieldCultivationSnapshot::new(
            1,
            1,
            1,
            "C",
            None,
            1.0,
            date!(2026-01-01),
            date!(2026-01-10),
            None,
            0,
            None,
            None,
        );

        let source = PlanAllocationAdjustReadSnapshotParts::build_field_source_snapshots(
            &plan_field_snapshots,
            &[field_cultivation],
        )[0]
        .cultivations[0]
        .clone();

        assert_eq!(source.cultivation_days, 10);
        assert!(!source.has_growth_stages);
        assert!(source.estimated_cost.abs() < 0.001);
    }

    // Ruby: test "plan_crop_snapshot invokes build_agrr_requirement only when crop has growth stages"
    #[test]
    fn plan_crop_snapshot_invokes_build_agrr_requirement_only_when_crop_has_growth_stages() {
        let mut called = false;
        let entry = PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
            1,
            "Tomato",
            json!([]),
            2,
            Some(|| {
                called = true;
                json!({ "stages": [] })
            }),
        );

        assert!(called);
        assert!(entry.has_growth_stages);
        assert_eq!(entry.agrr_requirement, Some(json!({ "stages": [] })));

        called = false;
        let entry = PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
            2,
            "Bare",
            json!([]),
            0,
            Some(|| {
                called = true;
                json!({})
            }),
        );

        assert!(!called);
        assert!(!entry.has_growth_stages);
        assert!(entry.agrr_requirement.is_none());
    }

    // Ruby: test "effective_cultivation_days returns stored value when present"
    #[test]
    fn effective_cultivation_days_returns_stored_value_when_present() {
        let days = PlanAllocationAdjustReadSnapshotParts::effective_cultivation_days(
            Some(15),
            date!(2026-04-01),
            date!(2026-04-30),
        );
        assert_eq!(days, 15);
    }

    // Ruby: test "effective_cultivation_days derives inclusive days from date range when stored is nil"
    #[test]
    fn effective_cultivation_days_derives_inclusive_days_from_date_range_when_stored_is_nil() {
        let days = PlanAllocationAdjustReadSnapshotParts::effective_cultivation_days(
            None,
            date!(2026-04-01),
            date!(2026-04-20),
        );
        assert_eq!(days, 20);
    }

    // Ruby: test "has_growth_stages? is true when crop_stage_count is positive"
    #[test]
    fn has_growth_stages_is_true_when_crop_stage_count_is_positive() {
        assert!(PlanAllocationAdjustReadSnapshotParts::has_growth_stages(2));
    }

    // Ruby: test "has_growth_stages? is false when crop_stage_count is zero"
    #[test]
    fn has_growth_stages_is_false_when_crop_stage_count_is_zero() {
        assert!(!PlanAllocationAdjustReadSnapshotParts::has_growth_stages(0));
    }

    // Ruby: test "weather_location_facts reads WeatherLocation DTO"
    #[test]
    fn weather_location_facts_reads_weather_location_dto() {
        let wl = WeatherLocation::new(
            9,
            35.0,
            135.0,
            Some(10.0),
            Some("Asia/Tokyo".into()),
        );

        let facts = PlanAllocationAdjustReadSnapshotParts::weather_location_facts(&wl);

        assert!((facts["latitude"].as_f64().unwrap() - 35.0).abs() < 0.001);
        assert!((facts["longitude"].as_f64().unwrap() - 135.0).abs() < 0.001);
        assert!((facts["elevation"].as_f64().unwrap() - 10.0).abs() < 0.001);
        assert_eq!(facts["timezone"].as_str(), Some("Asia/Tokyo"));
    }
