use crate::shared::hash::blank_attr;
use crate::shared::record_ref::RecordRef;
use crate::shared::attr::AttrValue;

const ALLOWED_REGIONS: &[&str] = &["jp", "us", "in"];

/// Ruby: `Domain::Pest::Entities::PestEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct PestEntity {
    pub id: i64,
    pub user_id: Option<i64>,
    pub name: String,
    pub name_scientific: Option<String>,
    pub family: Option<String>,
    pub order: Option<String>,
    pub description: Option<String>,
    pub occurrence_season: Option<String>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct PestEntityAttrs {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub name: String,
    pub name_scientific: Option<String>,
    pub family: Option<String>,
    pub order: Option<String>,
    pub description: Option<String>,
    pub occurrence_season: Option<String>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl PestEntity {
    pub fn new(attrs: PestEntityAttrs) -> Result<Self, String> {
        let id = attrs.id.ok_or_else(|| "id is required".to_string())?;
        let entity = Self {
            id,
            user_id: attrs.user_id,
            name: attrs.name,
            name_scientific: attrs.name_scientific,
            family: attrs.family,
            order: attrs.order,
            description: attrs.description,
            occurrence_season: attrs.occurrence_season,
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

    pub fn to_hash(&self) -> std::collections::BTreeMap<&'static str, serde_json::Value> {
        let mut h = std::collections::BTreeMap::new();
        h.insert("id", serde_json::json!(self.id));
        h.insert("name", serde_json::json!(self.name));
        h.insert("name_scientific", serde_json::json!(self.name_scientific));
        h.insert("family", serde_json::json!(self.family));
        h.insert("order", serde_json::json!(self.order));
        h.insert("description", serde_json::json!(self.description));
        h.insert("occurrence_season", serde_json::json!(self.occurrence_season));
        h.insert("is_reference", serde_json::json!(self.is_reference));
        h.insert("created_at", serde_json::json!(self.created_at));
        h.insert("updated_at", serde_json::json!(self.updated_at));
        h
    }

    /// Ruby: `PestEntity.recent(pests)`
    pub fn recent(mut pests: Vec<Self>) -> Vec<Self> {
        pests.sort_by(|a, b| {
            let ta = a.created_at_ts();
            let tb = b.created_at_ts();
            tb.cmp(&ta)
        });
        pests
    }

    fn created_at_ts(&self) -> i64 {
        self.created_at
            .as_deref()
            .and_then(|s| s.parse().ok())
            .unwrap_or(0)
    }

    fn validate(&self) -> Result<(), String> {
        if blank_attr(&AttrValue::Str(self.name.clone())) {
            return Err("Name is required".into());
        }
        if let Some(ref region) = self.region {
            if !ALLOWED_REGIONS.contains(&region.as_str()) {
                return Err(format!(
                    "Region must be one of: {}",
                    ALLOWED_REGIONS.join(", ")
                ));
            }
        }
        Ok(())
    }
}

impl RecordRef for PestEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[cfg(test)]
mod entities_pest_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/entities_pest_entity_test.rs"));
}
