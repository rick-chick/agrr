// Tests for `mappers/agrr_adjust_allocation_row_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::PlanAllocationAdjustFieldCultivationAllocationSnapshot;
    use time::macros::date;

    // Ruby: test "build_current_allocation excludes ids and cultivations without growth stages"
    #[test]
    fn build_current_allocation_excludes_ids_and_cultivations_without_growth_stages() {
        let included = PlanAllocationAdjustFieldCultivationAllocationSnapshot::new(
            10,
            1,
            "5",
            "Tomato",
            None,
            12.0,
            date!(2026-04-01),
            date!(2026-04-20),
            20,
            100.0,
            200.0,
            1.0,
            true,
        );
        let excluded_id = PlanAllocationAdjustFieldCultivationAllocationSnapshot::new(
            11,
            1,
            "6",
            "Skip",
            None,
            1.0,
            date!(2026-05-01),
            date!(2026-05-02),
            2,
            1.0,
            2.0,
            0.0,
            true,
        );
        let no_stages = PlanAllocationAdjustFieldCultivationAllocationSnapshot::new(
            12,
            1,
            "7",
            "NoStages",
            None,
            1.0,
            date!(2026-06-01),
            date!(2026-06-02),
            2,
            1.0,
            2.0,
            0.0,
            false,
        );
        let field_snapshot = PlanAllocationAdjustFieldSourceSnapshot::new(
            1,
            "North",
            100.0,
            vec![included, excluded_id, no_stages],
        );

        let payload = build_current_allocation(99, &[field_snapshot], &[11]);

        let schedules = payload["optimization_result"]["field_schedules"]
            .as_array()
            .unwrap();
        assert_eq!(schedules.len(), 1);
        let allocations = schedules[0]["allocations"].as_array().unwrap();
        assert_eq!(allocations.len(), 1);
        assert_eq!(allocations[0]["allocation_id"], 10);
        assert!((allocations[0]["profit"].as_f64().unwrap() - 100.0).abs() < 0.001);
    }
