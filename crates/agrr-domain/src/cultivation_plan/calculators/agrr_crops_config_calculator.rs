//! Ruby: `Domain::CultivationPlan::Calculators::AgrrCropsConfigCalculator`

use serde_json::{json, Map, Value};

pub trait AgrrCropsConfigLogger {
    fn warn(&self, message: &str);
}

#[derive(Debug, Clone)]
pub struct AgrrCropConfigEntry {
    pub crop_id: String,
    pub crop_name: String,
    pub has_growth_stages: bool,
    pub requirement: Option<Value>,
}

pub fn build(entries: &[AgrrCropConfigEntry], logger: Option<&dyn AgrrCropsConfigLogger>) -> Vec<Value> {
    entries
        .iter()
        .filter_map(|entry| {
            if !entry.has_growth_stages {
                logger.map(|l| {
                    l.warn(&format!(
                        "⚠️ [AGRR] Skipping crop '{}' (id={}): no growth stages",
                        entry.crop_name, entry.crop_id
                    ));
                });
                return None;
            }

            let mut crop_data = match &entry.requirement {
                Some(Value::Object(map)) => Value::Object(map.clone()),
                _ => json!({}),
            };
            if let Value::Object(ref mut map) = crop_data {
                let crop_obj = map
                    .entry("crop")
                    .or_insert_with(|| Value::Object(Map::new()));
                if let Value::Object(ref mut crop_map) = crop_obj {
                    crop_map.insert("crop_id".into(), Value::String(entry.crop_id.clone()));
                }
            }
            Some(crop_data)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
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
}
