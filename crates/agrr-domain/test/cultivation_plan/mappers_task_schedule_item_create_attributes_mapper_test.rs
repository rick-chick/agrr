// Tests for `mappers/task_schedule_item_create_attributes_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
    use crate::cultivation_plan::policies::task_schedule_item_create_policy::TaskScheduleItemCreateAttributes;
    use crate::shared::attr::{attr_map_from_pairs, AttrValue};

    #[test]
    fn attrs_to_params_converts_attr_map_values_to_optional_strings() {
        let attrs = attr_map_from_pairs([
            ("name", AttrValue::Str("作業A".into())),
            ("field_cultivation_id", AttrValue::Int(7)),
            ("manual", AttrValue::Bool(true)),
            ("cleared", AttrValue::Null),
        ]);

        let params = attrs_to_params(&attrs);

        assert_eq!(params.get("name").and_then(|v| v.as_deref()), Some("作業A"));
        assert_eq!(params.get("field_cultivation_id").and_then(|v| v.as_deref()), Some("7"));
        assert_eq!(params.get("manual").and_then(|v| v.as_deref()), Some("true"));
        assert_eq!(params.get("cleared"), Some(&None));
    }

    #[test]
    fn create_attrs_to_attr_map_maps_gateway_fields() {
        let attrs = TaskScheduleItemCreateAttributes {
            field_cultivation_id: Some(1),
            task_type: FIELD_WORK.into(),
            name: "作業A".into(),
            description: None,
            scheduled_date: Some("2026-07-05".into()),
            stage_name: None,
            stage_order: None,
            priority: None,
            source: "manual_entry".into(),
            weather_dependency: None,
            time_per_sqm: None,
            amount: None,
            amount_unit: None,
            agricultural_task_id: None,
            cultivation_plan_crop_id: None,
        };

        let map = create_attrs_to_attr_map(&attrs);

        assert_eq!(map.get("field_cultivation_id"), Some(&AttrValue::Int(1)));
        assert_eq!(map.get("task_type"), Some(&AttrValue::Str(FIELD_WORK.into())));
        assert_eq!(map.get("name"), Some(&AttrValue::Str("作業A".into())));
        assert_eq!(
            map.get("scheduled_date"),
            Some(&AttrValue::Str("2026-07-05".into()))
        );
    }

    #[test]
    fn create_attrs_to_attr_map_omits_optional_fields_when_absent() {
        let attrs = TaskScheduleItemCreateAttributes {
            field_cultivation_id: None,
            task_type: FIELD_WORK.into(),
            name: "作業B".into(),
            description: None,
            scheduled_date: None,
            stage_name: None,
            stage_order: None,
            priority: None,
            source: "manual_entry".into(),
            weather_dependency: None,
            time_per_sqm: None,
            amount: None,
            amount_unit: None,
            agricultural_task_id: None,
            cultivation_plan_crop_id: None,
        };

        let map = create_attrs_to_attr_map(&attrs);

        assert!(!map.contains_key("field_cultivation_id"));
        assert!(!map.contains_key("scheduled_date"));
        assert_eq!(map.get("name"), Some(&AttrValue::Str("作業B".into())));
    }
