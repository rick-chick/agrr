// Tests for `calculators/fields_allocation.rs` (fail-closed characterization per docs/spec-defects/06).

    use crate::cultivation_plan::calculators::fields_allocation::FieldsAllocation;
    use crate::cultivation_plan::dtos::CultivationPlanInitCrop;

    fn crop(id: i64, name: &str, area_per_unit: f64) -> CultivationPlanInitCrop {
        CultivationPlanInitCrop {
            id,
            name: name.into(),
            variety: None,
            area_per_unit,
            revenue_per_area: 0.0,
        }
    }

    #[test]
    fn allocate_uses_default_crop_and_minimum_area_when_crops_empty() {
        let allocations = FieldsAllocation::new(30.0, &[]).allocate();
        assert_eq!(allocations.len(), 1);
        assert_eq!(allocations[0].crop.id, 0);
        assert_eq!(allocations[0].crop.name, "デフォルト作物");
        assert_eq!(allocations[0].area, 100.0);
    }

    #[test]
    fn allocate_uses_max_of_total_area_and_100_when_total_area_non_positive() {
        let crops = [crop(1, "Tomato", 10.0)];
        let allocations = FieldsAllocation::new(0.0, &crops).allocate();
        assert_eq!(allocations.len(), 1);
        assert_eq!(allocations[0].crop.id, 1);
        assert_eq!(allocations[0].area, 100.0);
    }

    #[test]
    fn allocate_splits_area_by_prioritized_crops_when_inputs_valid() {
        let crops = [
            crop(1, "Small plot crop", 10.0),
            crop(2, "Large plot crop", 20.0),
        ];
        let allocations = FieldsAllocation::new(250.0, &crops).allocate();
        assert_eq!(allocations.len(), 2);
        assert_eq!(allocations[0].crop.id, 2);
        assert_eq!(allocations[1].crop.id, 1);
        assert_eq!(allocations[0].area, 125.0);
        assert_eq!(allocations[1].area, 125.0);
    }

    #[test]
    fn field_count_respects_max_fields_constant() {
        let crops = [
            crop(1, "A", 10.0),
            crop(2, "B", 10.0),
            crop(3, "C", 10.0),
            crop(4, "D", 10.0),
            crop(5, "E", 10.0),
            crop(6, "F", 10.0),
        ];
        assert_eq!(FieldsAllocation::new(1_000.0, &crops).field_count(), 5);
    }
