// Tests for `policies/task_schedule_item_create_policy.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::TaskScheduleAgriculturalTaskSnapshot;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    // Ruby: test "validate_crop_selection! passes when crop ids match"
    #[test]
    fn validate_crop_selection_passes_when_crop_ids_match() {
        assert!(validate_crop_selection(Some(5), Some(5)).is_ok());
    }

    // Ruby: test "validate_crop_selection! raises when crop ids mismatch"
    #[test]
    fn validate_crop_selection_raises_when_crop_ids_mismatch() {
        let err = validate_crop_selection(Some(5), Some(9)).unwrap_err();
        assert!(err
            .errors
            .as_ref()
            .unwrap()
            .get("base")
            .first()
            .unwrap()
            .contains('物'));
    }

    #[test]
    fn validate_agricultural_task_raises_when_task_id_submitted_but_not_found() {
        assert!(validate_agricultural_task(Some(99), None).is_err());
    }

    #[test]
    fn validate_agricultural_task_passes_when_task_found() {
        let task = TaskScheduleAgriculturalTaskSnapshot {
            id: 3,
            name: "作業".into(),
            description: None,
            task_type: Some(FIELD_WORK.into()),
            weather_dependency: None,
            time_per_sqm: None,
        };
        assert!(validate_agricultural_task(Some(3), Some(&task)).is_ok());
    }

    // Ruby: test "build_create_attributes uses template name when name omitted"
    #[test]
    fn build_create_attributes_uses_agricultural_task_name_when_name_omitted() {
        let task = TaskScheduleAgriculturalTaskSnapshot {
            id: 3,
            name: "作業A".into(),
            description: Some("説明".into()),
            task_type: Some(FIELD_WORK.into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(Decimal::from_str("0.2").unwrap()),
        };
        let mut params = BTreeMap::new();
        params.insert("field_cultivation_id".into(), Some("1".into()));
        params.insert("name".into(), None);

        let attrs = build_create_attributes(&params, Some(&task)).unwrap();
        assert_eq!(attrs.name, "作業A");
        assert_eq!(attrs.source, "agricultural_task_entry");
        assert_eq!(attrs.agricultural_task_id, Some(3));
    }
