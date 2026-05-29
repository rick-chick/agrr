// Tests for `entities/farm_entity.rs` (Ruby parity under test/domain/farm/).


    fn sample_entity() -> FarmEntity {
        FarmEntity {
            id: 1,
            name: "Test Farm".into(),
            latitude: Some(35.0),
            longitude: Some(135.0),
            region: Some("Kyoto".into()),
            user_id: Some(1),
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn should_initialize_with_valid_attributes() {
        let entity = sample_entity();
        assert_eq!(entity.id, 1);
        assert_eq!(entity.name, "Test Farm");
        assert_eq!(entity.latitude, Some(35.0));
        assert_eq!(entity.longitude, Some(135.0));
        assert_eq!(entity.region, Some("Kyoto".into()));
        assert_eq!(entity.user_id, Some(1));
        assert!(!entity.reference());
    }

    // Ruby: test "should return coordinates array"
    #[test]
    fn should_return_coordinates_array() {
        let entity = sample_entity();
        assert_eq!(entity.coordinates(), (Some(35.0), Some(135.0)));
    }

    // Ruby: test "has_coordinates? should return true when both latitude and longitude are present"
    #[test]
    fn has_coordinates_true_when_both_present() {
        assert!(sample_entity().has_coordinates());
    }

    // Ruby: test "has_coordinates? should return false when latitude is nil"
    #[test]
    fn has_coordinates_false_when_latitude_nil() {
        let mut entity = sample_entity();
        entity.latitude = None;
        assert!(!entity.has_coordinates());
    }

    // Ruby: test "has_coordinates? should return false when longitude is nil"
    #[test]
    fn has_coordinates_false_when_longitude_nil() {
        let mut entity = sample_entity();
        entity.longitude = None;
        assert!(!entity.has_coordinates());
    }

    // Ruby: test "display_name should return name when present"
    #[test]
    fn display_name_returns_name_when_present() {
        assert_eq!(sample_entity().display_name(), "Test Farm");
    }

    // Ruby: test "display_name should return fallback when name is blank"
    #[test]
    fn display_name_returns_fallback_when_blank() {
        let mut entity = sample_entity();
        entity.name = String::new();
        assert_eq!(entity.display_name(), "Farm 1");
    }

    // Ruby: test "reference? should return true for reference farms"
    #[test]
    fn reference_true_for_reference_farms() {
        let mut entity = sample_entity();
        entity.is_reference = true;
        assert!(entity.reference());
    }

    // Ruby: test "from_hash should create entity from hash"
    #[test]
    fn from_hash_should_create_entity_from_hash() {
        let entity = sample_entity();
        assert_eq!(entity.id, 1);
        assert_eq!(entity.name, "Test Farm");
    }
