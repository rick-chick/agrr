// Tests for `entities/pest_entity.rs` (Ruby parity under test/domain/pest/).


    fn base_attrs() -> PestEntityAttrs {
        PestEntityAttrs {
            id: Some(1),
            user_id: Some(123),
            name: "Test Pest".into(),
            name_scientific: Some("Testus pestus".into()),
            family: Some("Testidae".into()),
            order: Some("Testales".into()),
            description: Some("A test pest".into()),
            occurrence_season: Some("Spring".into()),
            region: Some("jp".into()),
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, 1);
        assert_eq!(entity.user_id, Some(123));
        assert_eq!(entity.name, "Test Pest");
        assert_eq!(entity.name_scientific.as_deref(), Some("Testus pestus"));
        assert_eq!(entity.family.as_deref(), Some("Testidae"));
        assert_eq!(entity.order.as_deref(), Some("Testales"));
        assert_eq!(entity.description.as_deref(), Some("A test pest"));
        assert_eq!(entity.occurrence_season.as_deref(), Some("Spring"));
        assert_eq!(entity.region.as_deref(), Some("jp"));
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = PestEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn raises_when_name_blank() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = PestEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn raises_when_region_invalid() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = PestEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should accept valid regions"
    #[test]
    fn accepts_valid_regions() {
        for region in ["jp", "us", "in"] {
            let mut attrs = base_attrs();
            attrs.region = Some(region.into());
            let entity = PestEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(region));
        }
    }

    // Ruby: test "reference? returns true when is_reference is true"
    #[test]
    fn reference_true_when_is_reference_true() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }

    // Ruby: test "reference? returns false when is_reference is false"
    #[test]
    fn reference_false_when_is_reference_false() {
        let mut attrs = base_attrs();
        attrs.is_reference = false;
        let entity = PestEntity::new(attrs).expect("valid");
        assert!(!entity.reference());
    }

    // Ruby: test "to_hash returns expected hash"
    #[test]
    fn to_hash_returns_expected_fields() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        let h = entity.to_hash();
        assert_eq!(h.get("id"), Some(&serde_json::json!(1)));
        assert_eq!(h.get("name"), Some(&serde_json::json!("Test Pest")));
        assert_eq!(h.get("is_reference"), Some(&serde_json::json!(true)));
        assert!(!h.contains_key("region"));
        assert!(!h.contains_key("user_id"));
    }
