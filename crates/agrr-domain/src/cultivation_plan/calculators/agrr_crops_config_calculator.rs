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
mod calculators_agrr_crops_config_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_agrr_crops_config_calculator_test.rs"));
}
