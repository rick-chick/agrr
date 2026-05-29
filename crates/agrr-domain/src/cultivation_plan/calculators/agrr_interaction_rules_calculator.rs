//! Ruby: `Domain::CultivationPlan::Calculators::AgrrInteractionRulesCalculator`

use std::collections::{BTreeMap, BTreeSet};

use serde_json::{json, Value};

pub fn build(crop_groups: &BTreeMap<String, Vec<String>>, random_hex: &str) -> Vec<Value> {
    let mut rules = Vec::new();
    for groups in crop_groups.values() {
        for group in groups {
            rules.push(json!({
                "rule_id": format!("continuous_{group}_{random_hex}"),
                "rule_type": "continuous_cultivation",
                "source_group": group,
                "target_group": group,
                "impact_ratio": 0.7,
                "is_directional": true,
                "description": format!("Continuous cultivation penalty for {group}"),
            }));
        }
    }

    let mut seen = BTreeSet::new();
    rules
        .into_iter()
        .filter(|rule| {
            let key = (
                rule["source_group"].as_str().unwrap_or("").to_string(),
                rule["target_group"].as_str().unwrap_or("").to_string(),
            );
            seen.insert(key)
        })
        .collect()
}

#[cfg(test)]
mod calculators_agrr_interaction_rules_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_agrr_interaction_rules_calculator_test.rs"));
}
