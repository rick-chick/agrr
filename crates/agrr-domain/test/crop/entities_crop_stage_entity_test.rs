// Tests for `entities/crop_stage_entity.rs` (Ruby parity under test/domain/crop/).


    // Ruby: test "raises when name is blank"
    #[test]
    fn raises_when_name_is_blank() {
        assert!(CropStageEntity::new(1, 1, "  ", 0).is_err());
    }

    // Ruby: test "raises when crop_id is nil"
    #[test]
    fn raises_when_crop_id_is_nil() {
        assert!(CropStageEntity::new(1, 0, "Stage", 0).is_err());
    }

    // Ruby: test "raises when order is nil"
    #[test]
    fn raises_when_order_is_nil() {
        // Rust uses i32; nil order represented as missing — use Option in builder if needed.
        // Ruby rejects nil order; we validate via dedicated constructor accepting Option.
        assert!(CropStageEntity::try_new_optional_order(1, 1, "Stage", None).is_err());
    }

    // Ruby: test "creates entity with valid attributes"
    #[test]
    fn creates_entity_with_valid_attributes() {
        let entity = CropStageEntity::new(1, 10, "Vegetative", 1).unwrap();
        assert_eq!(entity.name, "Vegetative");
        assert_eq!(entity.crop_id, 10);
        assert_eq!(entity.order, 1);
    }

    // Ruby: test "stores nested requirements when provided"
    #[test]
    fn stores_nested_requirements_when_provided() {
        let mut entity = CropStageEntity::new(1, 10, "Stage", 0).unwrap();
        entity.thermal_requirement = Some(
            ThermalRequirementEntity::new(1, 10, rust_decimal::Decimal::from(200)).unwrap(),
        );
        assert!(entity.thermal_requirement.is_some());
    }
