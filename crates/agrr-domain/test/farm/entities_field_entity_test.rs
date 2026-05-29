// Tests for `entities/field_entity.rs` (Ruby parity under test/domain/farm/).


    fn sample_entity() -> FieldEntity {
        FieldEntity {
            id: 1,
            name: "Test Field".into(),
            area: Some(100.0),
            daily_fixed_cost: Some(50.0),
            region: Some("Kyoto".into()),
            farm_id: 1,
            user_id: Some(1),
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn should_initialize_with_valid_attributes() {
        let entity = sample_entity();
        assert_eq!(entity.id, 1);
        assert_eq!(entity.name, "Test Field");
        assert_eq!(entity.area, Some(100.0));
        assert_eq!(entity.daily_fixed_cost, Some(50.0));
        assert_eq!(entity.region, Some("Kyoto".into()));
        assert_eq!(entity.farm_id, 1);
        assert_eq!(entity.user_id, Some(1));
    }

    // Ruby: test "display_name should return name when present"
    #[test]
    fn display_name_returns_name_when_present() {
        assert_eq!(sample_entity().display_name(), "Test Field");
    }

    // Ruby: test "display_name should return fallback when name is blank"
    #[test]
    fn display_name_returns_fallback_when_blank() {
        let mut entity = sample_entity();
        entity.name = String::new();
        assert_eq!(entity.display_name(), "Field 1");
    }

    // Ruby: test "from_hash should create entity from hash"
    #[test]
    fn from_hash_should_create_entity_from_hash() {
        let entity = sample_entity();
        assert_eq!(entity.id, 1);
        assert_eq!(entity.name, "Test Field");
    }
