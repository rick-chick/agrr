use std::collections::BTreeMap;

use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::hash::{blank_attr, present_attr};
use crate::shared::record_ref::RecordRef;

/// Ruby: `Domain::InteractionRule::Entities::InteractionRuleEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct InteractionRuleEntity {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub rule_type: String,
    pub source_group: String,
    pub target_group: String,
    pub impact_ratio: f64,
    pub is_directional: Option<bool>,
    pub description: Option<String>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl InteractionRuleEntity {
    pub fn new(attrs: InteractionRuleEntityAttrs) -> Result<Self, String> {
        let entity = Self {
            id: attrs.id,
            user_id: attrs.user_id,
            rule_type: attrs.rule_type,
            source_group: attrs.source_group,
            target_group: attrs.target_group,
            impact_ratio: attrs.impact_ratio,
            is_directional: attrs.is_directional,
            description: attrs.description,
            region: attrs.region,
            is_reference: attrs.is_reference,
            created_at: attrs.created_at,
            updated_at: attrs.updated_at,
        };
        entity.validate()?;
        Ok(entity)
    }

    pub fn reference(&self) -> bool {
        self.is_reference
    }

    pub fn to_hash(&self) -> AttrMap {
        let mut h = BTreeMap::new();
        if let Some(id) = self.id {
            h.insert("id".into(), AttrValue::Int(id));
        }
        match self.user_id {
            Some(uid) => h.insert("user_id".into(), AttrValue::Int(uid)),
            None => h.insert("user_id".into(), AttrValue::Null),
        };
        h.insert("rule_type".into(), AttrValue::from(self.rule_type.as_str()));
        h.insert(
            "source_group".into(),
            AttrValue::from(self.source_group.as_str()),
        );
        h.insert(
            "target_group".into(),
            AttrValue::from(self.target_group.as_str()),
        );
        h.insert("impact_ratio".into(), AttrValue::Str(self.impact_ratio.to_string()));
        if let Some(v) = self.is_directional {
            h.insert("is_directional".into(), AttrValue::Bool(v));
        }
        if let Some(ref d) = self.description {
            h.insert("description".into(), AttrValue::from(d.as_str()));
        }
        if let Some(ref r) = self.region {
            h.insert("region".into(), AttrValue::from(r.as_str()));
        }
        h.insert("is_reference".into(), AttrValue::Bool(self.is_reference));
        if let Some(ref t) = self.created_at {
            h.insert("created_at".into(), AttrValue::from(t.as_str()));
        }
        if let Some(ref t) = self.updated_at {
            h.insert("updated_at".into(), AttrValue::from(t.as_str()));
        }
        h
    }

    fn validate(&self) -> Result<(), String> {
        if blank_attr(&AttrValue::from(self.rule_type.as_str()))
            || blank_attr(&AttrValue::from(self.source_group.as_str()))
            || blank_attr(&AttrValue::from(self.target_group.as_str()))
        {
            return Err(
                "rule_type, source_group, target_group, impact_ratio are required".into(),
            );
        }
        if let Some(ref region) = self.region {
            if present_attr(&AttrValue::from(region.as_str()))
                && !["jp", "us", "in"].contains(&region.as_str())
            {
                return Err("region must be one of jp, us, in".into());
            }
        }
        Ok(())
    }
}

impl RecordRef for InteractionRuleEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[derive(Debug, Clone, Default)]
pub struct InteractionRuleEntityAttrs {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub rule_type: String,
    pub source_group: String,
    pub target_group: String,
    pub impact_ratio: f64,
    pub is_directional: Option<bool>,
    pub description: Option<String>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

#[cfg(test)]
mod entities_interaction_rule_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/interaction_rule/entities_interaction_rule_entity_test.rs"));
}
