use crate::shared::hash::blank_attr;
use crate::shared::record_ref::RecordRef;

const VALID_REGIONS: &[&str] = &["jp", "us", "in"];

/// Ruby: `Domain::AgriculturalTask::Entities::AgriculturalTaskEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct AgriculturalTaskEntity {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Vec<String>,
    pub skill_level: Option<String>,
    pub region: Option<String>,
    pub task_type: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct AgriculturalTaskEntityAttrs {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Vec<String>,
    pub skill_level: Option<String>,
    pub region: Option<String>,
    pub task_type: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl AgriculturalTaskEntity {
    pub fn new(attrs: AgriculturalTaskEntityAttrs) -> Result<Self, String> {
        let entity = Self {
            id: attrs.id,
            user_id: attrs.user_id,
            name: attrs.name,
            description: attrs.description,
            time_per_sqm: attrs.time_per_sqm,
            weather_dependency: attrs.weather_dependency,
            required_tools: attrs.required_tools,
            skill_level: attrs.skill_level,
            region: attrs.region,
            task_type: attrs.task_type,
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

    pub fn to_param(&self) -> String {
        self.id.map(|id| id.to_string()).unwrap_or_default()
    }

    fn validate(&self) -> Result<(), String> {
        if blank_attr(&crate::shared::attr::AttrValue::Str(self.name.clone())) {
            return Err("Name is required".into());
        }
        if let Some(ref region) = self.region {
            if !VALID_REGIONS.contains(&region.as_str()) {
                return Err("Region must be one of: jp, us, in".into());
            }
        }
        Ok(())
    }
}

impl RecordRef for AgriculturalTaskEntity {
    fn is_reference(&self) -> bool {
        self.reference()
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[cfg(test)]
mod entities_agricultural_task_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/entities_agricultural_task_entity_test.rs"));
}
