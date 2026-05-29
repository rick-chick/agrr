// Tests for `mappers/plan_save_interaction_rule_attributes_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "attributes_for_create maps reference row to user rule attributes"
    #[test]
    fn attributes_for_create_maps_reference_row_to_user_rule_attributes() {
        let row = PublicPlanSaveInteractionRuleReferenceRow::new(
            42,
            "continuous_cultivation",
            "GroupSrc",
            "GroupTgt",
            0.7,
            false,
            Some("jp".into()),
            Some("連作説明".into()),
        );

        let attrs = attributes_for_create(&row);

        assert_eq!(attrs["rule_type"].as_str(), Some("continuous_cultivation"));
        assert_eq!(attrs["source_group"].as_str(), Some("GroupSrc"));
        assert_eq!(attrs["target_group"].as_str(), Some("GroupTgt"));
        assert!((attrs["impact_ratio"].as_f64().unwrap() - 0.7).abs() < 0.0001);
        assert_eq!(attrs["is_directional"].as_bool(), Some(false));
        assert_eq!(attrs["region"].as_str(), Some("jp"));
        assert_eq!(attrs["description"].as_str(), Some("連作説明"));
        assert_eq!(attrs["is_reference"].as_bool(), Some(false));
        assert_eq!(attrs["source_interaction_rule_id"].as_i64(), Some(42));
    }
