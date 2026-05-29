// Tests for `entities/fertilize_entity.rs` (Ruby parity under test/domain/fertilize/).


    fn base_attrs() -> FertilizeEntityAttrs {
        FertilizeEntityAttrs {
            id: Some(1),
            user_id: None,
            name: "尿素".into(),
            n: Some(46.0),
            p: None,
            k: None,
            description: Some("窒素肥料".into()),
            package_size: Some(25.0),
            region: None,
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name, "尿素");
        assert_eq!(entity.n, Some(46.0));
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil package_size"
    #[test]
    fn initializes_with_nil_package_size() {
        let mut attrs = base_attrs();
        attrs.package_size = None;
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert!(entity.package_size.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn raises_when_name_blank() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = FertilizeEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "has_nutrient? should return true when nutrient is present and > 0"
    #[test]
    fn has_nutrient_returns_true_when_present() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert!(entity.has_nutrient("n"));
        assert!(!entity.has_nutrient("p"));
        assert!(!entity.has_nutrient("k"));
    }

    // Ruby: test "npk_summary should return formatted string"
    #[test]
    fn npk_summary_formatted() {
        let mut attrs = base_attrs();
        attrs.n = Some(20.0);
        attrs.p = Some(10.0);
        attrs.k = Some(5.0);
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert_eq!(entity.npk_summary(), "20-10-5");
    }

    // Ruby: test "npk_summary should handle nil values"
    #[test]
    fn npk_summary_handles_nil_values() {
        let mut attrs = base_attrs();
        attrs.n = Some(20.0);
        attrs.p = None;
        attrs.k = Some(10.0);
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert_eq!(entity.npk_summary(), "20-10");
    }

    // Ruby: test "reference? should return true for reference fertilizes"
    #[test]
    fn reference_returns_true_for_reference() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }
