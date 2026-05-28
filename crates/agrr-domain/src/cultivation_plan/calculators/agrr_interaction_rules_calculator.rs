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
mod tests {
    use super::*;

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
}
