// Tests for `policies/task_schedule_item_create_policy.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::TaskScheduleCropTaskTemplateSnapshot;
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

    // Ruby: test "validate_template! raises when template crop does not match field crop"
    #[test]
    fn validate_template_raises_when_template_crop_mismatch() {
        let template = TaskScheduleCropTaskTemplateSnapshot {
            id: 1,
            crop_id: 99,
            name: "T".into(),
            description: None,
            task_type: None,
            weather_dependency: None,
            time_per_sqm: None,
            agricultural_task_id: 1,
        };
        assert!(validate_template(Some(5), Some(&template)).is_err());
    }

    // Ruby: test "build_create_attributes uses template name when name omitted"
    #[test]
    fn build_create_attributes_uses_template_name_when_name_omitted() {
        let template = TaskScheduleCropTaskTemplateSnapshot {
            id: 1,
            crop_id: 5,
            name: "テンプレ作業".into(),
            description: Some("説明".into()),
            task_type: Some(FIELD_WORK.into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(Decimal::from_str("0.2").unwrap()),
            agricultural_task_id: 3,
        };
        let mut params = BTreeMap::new();
        params.insert("field_cultivation_id".into(), Some("1".into()));
        params.insert("name".into(), None);

        let attrs = build_create_attributes(&params, Some(&template)).unwrap();
        assert_eq!(attrs.name, "テンプレ作業");
        assert_eq!(attrs.source, "template_entry");
    }
