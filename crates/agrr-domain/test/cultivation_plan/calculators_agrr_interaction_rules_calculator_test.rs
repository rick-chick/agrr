// Tests for `calculators/agrr_interaction_rules_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "build generates unique rules with injected random"
    #[test]
    fn build_generates_unique_rules_with_injected_random() {
        let mut crop_groups = BTreeMap::new();
        crop_groups.insert("1".into(), vec!["leafy".into(), "leafy".into()]);
        crop_groups.insert("2".into(), vec!["root".into()]);

        let result = build(&crop_groups, "abcd1234");
        assert_eq!(result.len(), 2);
        let rule_ids: Vec<_> = result
            .iter()
            .filter_map(|r| r["rule_id"].as_str())
            .collect();
        assert!(rule_ids.contains(&"continuous_leafy_abcd1234"));
        assert!(rule_ids.contains(&"continuous_root_abcd1234"));
    }
