//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveInteractionRuleAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow;

pub fn attributes_for_create(
    row: &PublicPlanSaveInteractionRuleReferenceRow,
) -> BTreeMap<String, Value> {
    BTreeMap::from([
        ("rule_type".into(), json!(row.rule_type)),
        ("source_group".into(), json!(row.source_group)),
        ("target_group".into(), json!(row.target_group)),
        ("impact_ratio".into(), json!(row.impact_ratio)),
        ("is_directional".into(), json!(row.is_directional)),
        ("region".into(), json!(row.region)),
        ("description".into(), json!(row.description)),
        ("is_reference".into(), json!(false)),
        (
            "source_interaction_rule_id".into(),
            json!(row.reference_interaction_rule_id),
        ),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
