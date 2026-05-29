// Tests for `entities/agricultural_task_entity.rs` (Ruby parity under test/domain/agricultural_task/).


    fn base_attrs() -> AgriculturalTaskEntityAttrs {
        AgriculturalTaskEntityAttrs {
            id: Some(1),
            user_id: Some(1),
            name: "Test Task".into(),
            description: Some("Test description".into()),
            time_per_sqm: Some(0.5),
            weather_dependency: Some("sunny".into()),
            required_tools: vec!["tool1".into(), "tool2".into()],
            skill_level: Some("beginner".into()),
            region: Some("jp".into()),
            task_type: Some("planting".into()),
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = AgriculturalTaskEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name, "Test Task");
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn rejects_blank_name() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = AgriculturalTaskEntity::new(attrs).expect_err("invalid");
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn rejects_invalid_region() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = AgriculturalTaskEntity::new(attrs).expect_err("invalid");
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should accept valid regions jp, us, in"
    #[test]
    fn accepts_valid_regions() {
        for region in ["jp", "us", "in"] {
            let mut attrs = base_attrs();
            attrs.region = Some(region.into());
            let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(region));
        }
    }

    // Ruby: test "reference? should return true for reference tasks"
    #[test]
    fn reference_true_for_reference_tasks() {
        let entity = AgriculturalTaskEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }

    // Ruby: test "reference? should return false for non-reference tasks"
    #[test]
    fn reference_false_for_non_reference_tasks() {
        let mut attrs = base_attrs();
        attrs.is_reference = false;
        let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
        assert!(!entity.reference());
    }
