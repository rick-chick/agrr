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
mod mappers_plan_save_interaction_rule_attributes_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_plan_save_interaction_rule_attributes_mapper_test.rs"));
}
