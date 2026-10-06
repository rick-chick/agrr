// Tests for `calculators/agrr_crops_config_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).

use serde_json::json;

    use std::cell::RefCell;

    struct MockLogger {
        messages: RefCell<Vec<String>>,
    }

    impl AgrrCropsConfigLogger for MockLogger {
        fn warn(&self, message: &str) {
            self.messages.borrow_mut().push(message.to_string());
        }
    }

    // Ruby: test "build skips crops without stages and sets crop_id"
    #[test]
    fn build_skips_crops_without_stages_and_sets_crop_id() {
        let logger = MockLogger {
            messages: RefCell::new(vec![]),
        };
        let entries = vec![
            AgrrCropConfigEntry {
                crop_id: "10".into(),
                crop_name: "Tomato".into(),
                has_growth_stages: true,
                requirement: Some(json!({ "crop": { "name": "Tomato" } })),
            },
            AgrrCropConfigEntry {
                crop_id: "99".into(),
                crop_name: "NoStage".into(),
                has_growth_stages: false,
                requirement: None,
            },
        ];
        let result = build(&entries, Some(&logger));
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["crop"]["crop_id"], "10");
        assert_eq!(result[0]["crop"]["name"], "Tomato");
        assert_eq!(logger.messages.borrow().len(), 1);
    }

    // Locks fail-open behavior (docs/spec-defects/06 H1) until requirement-less crops are rejected.
    #[test]
    fn build_injects_crop_id_when_requirement_is_none_but_growth_stages_exist() {
        let entries = vec![AgrrCropConfigEntry {
            crop_id: "42".into(),
            crop_name: "Pepper".into(),
            has_growth_stages: true,
            requirement: None,
        }];
        let result = build(&entries, None);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["crop"]["crop_id"], "42");
        assert!(result[0].get("stages").is_none());
    }

    #[test]
    fn build_treats_non_object_requirement_as_empty_object_with_crop_id() {
        let entries = vec![AgrrCropConfigEntry {
            crop_id: "7".into(),
            crop_name: "Eggplant".into(),
            has_growth_stages: true,
            requirement: Some(json!([])),
        }];
        let result = build(&entries, None);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["crop"]["crop_id"], "7");
        assert!(result[0].as_object().unwrap().len() <= 1);
    }
