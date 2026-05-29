// Tests for `entities/pesticide_entity.rs` (Ruby parity under test/domain/pesticide/).


    fn base_attrs() -> PesticideEntityAttrs {
        PesticideEntityAttrs {
            id: 1,
            user_id: Some(2),
            name: "Test Pesticide".into(),
            active_ingredient: Some("Test Ingredient".into()),
            description: Some("Test Description".into()),
            crop_id: Some(3),
            pest_id: Some(4),
            region: Some("jp".into()),
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = PesticideEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, 1);
        assert_eq!(entity.user_id, Some(2));
        assert_eq!(entity.name, "Test Pesticide");
        assert_eq!(entity.active_ingredient.as_deref(), Some("Test Ingredient"));
        assert_eq!(entity.description.as_deref(), Some("Test Description"));
        assert_eq!(entity.crop_id, Some(3));
        assert_eq!(entity.pest_id, Some(4));
        assert_eq!(entity.region.as_deref(), Some("jp"));
        assert!(!entity.is_reference);
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = PesticideEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn raises_when_region_invalid() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = PesticideEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should initialize with valid regions"
    #[test]
    fn initializes_with_valid_regions() {
        for valid_region in VALID_REGIONS {
            let mut attrs = base_attrs();
            attrs.region = Some(valid_region.into());
            let entity = PesticideEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(valid_region));
        }
    }
