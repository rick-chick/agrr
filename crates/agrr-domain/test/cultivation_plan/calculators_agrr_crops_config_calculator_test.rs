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
