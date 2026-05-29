// Tests for `entities/interaction_rule_entity.rs` (Ruby parity under test/domain/interaction_rule/).


    fn valid_attrs() -> InteractionRuleEntityAttrs {
        InteractionRuleEntityAttrs {
            id: Some(1),
            user_id: Some(123),
            rule_type: "type1".into(),
            source_group: "group1".into(),
            target_group: "group2".into(),
            impact_ratio: 0.5,
            is_directional: Some(true),
            description: Some("Test rule".into()),
            region: Some("jp".into()),
            is_reference: false,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = InteractionRuleEntity::new(valid_attrs()).unwrap();
        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.user_id, Some(123));
        assert_eq!(entity.rule_type, "type1");
        assert_eq!(entity.source_group, "group1");
        assert_eq!(entity.target_group, "group2");
        assert_eq!(entity.impact_ratio, 0.5);
        assert_eq!(entity.is_directional, Some(true));
        assert_eq!(entity.description.as_deref(), Some("Test rule"));
        assert_eq!(entity.region.as_deref(), Some("jp"));
        assert!(!entity.is_reference);
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = valid_attrs();
        attrs.region = None;
        let entity = InteractionRuleEntity::new(attrs).unwrap();
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when required attributes are blank"
    #[test]
    fn rejects_blank_required_attributes() {
        let mut attrs = valid_attrs();
        attrs.rule_type = String::new();
        let err = InteractionRuleEntity::new(attrs).unwrap_err();
        assert_eq!(
            err,
            "rule_type, source_group, target_group, impact_ratio are required"
        );
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn rejects_invalid_region() {
        let mut attrs = valid_attrs();
        attrs.region = Some("invalid".into());
        let err = InteractionRuleEntity::new(attrs).unwrap_err();
        assert_eq!(err, "region must be one of jp, us, in");
    }

    // Ruby: test "should accept valid region values"
    #[test]
    fn accepts_valid_region_values() {
        for region in ["jp", "us", "in"] {
            let mut attrs = valid_attrs();
            attrs.region = Some(region.into());
            let entity = InteractionRuleEntity::new(attrs).unwrap();
            assert_eq!(entity.region.as_deref(), Some(region));
        }
    }

    // Ruby: test "reference? returns expected value"
    #[test]
    fn reference_returns_expected_value() {
        let mut attrs = valid_attrs();
        attrs.is_reference = true;
        let entity = InteractionRuleEntity::new(attrs).unwrap();
        assert!(entity.reference());
    }

    // Ruby: test "to_hash returns expected hash"
    #[test]
    fn to_hash_returns_expected_hash() {
        let entity = InteractionRuleEntity::new(valid_attrs()).unwrap();
        let h = entity.to_hash();
        assert_eq!(h.get("id"), Some(&AttrValue::Int(1)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(123)));
        assert_eq!(h.get("rule_type"), Some(&AttrValue::from("type1")));
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
    }
