//! Ruby: `Adapters::InteractionRule::Mappers::InteractionRuleAgrrMapper`

use serde_json::{json, Value};

use crate::interaction_rule::entities::InteractionRuleEntity;

pub fn to_agrr_format(rule: &InteractionRuleEntity) -> Value {
    let id = rule.id.unwrap_or(0);
    let mut obj = serde_json::Map::new();
    obj.insert("rule_id".into(), json!(format!("rule_{id}")));
    obj.insert("rule_type".into(), json!(rule.rule_type));
    obj.insert("source_group".into(), json!(rule.source_group));
    obj.insert("target_group".into(), json!(rule.target_group));
    obj.insert("impact_ratio".into(), json!(rule.impact_ratio));
    if let Some(v) = rule.is_directional {
        obj.insert("is_directional".into(), json!(v));
    }
    if let Some(ref d) = rule.description {
        obj.insert("description".into(), json!(d));
    }
    Value::Object(obj)
}

pub fn to_agrr_format_array(rules: &[InteractionRuleEntity]) -> Vec<Value> {
    rules.iter().map(to_agrr_format).collect()
}
