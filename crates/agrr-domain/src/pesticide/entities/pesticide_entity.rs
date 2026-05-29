use crate::shared::record_ref::RecordRef;

const VALID_REGIONS: [&str; 3] = ["jp", "us", "in"];

/// Ruby: `Domain::Pesticide::Entities::PesticideEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct PesticideEntity {
    pub id: i64,
    pub user_id: Option<i64>,
    pub name: String,
    pub active_ingredient: Option<String>,
    pub description: Option<String>,
    pub crop_id: Option<i64>,
    pub pest_id: Option<i64>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone)]
pub struct PesticideEntityAttrs {
    pub id: i64,
    pub user_id: Option<i64>,
    pub name: String,
    pub active_ingredient: Option<String>,
    pub description: Option<String>,
    pub crop_id: Option<i64>,
    pub pest_id: Option<i64>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: String,
    pub updated_at: String,
}

impl PesticideEntity {
    pub fn new(attrs: PesticideEntityAttrs) -> Result<Self, String> {
        let entity = Self {
            id: attrs.id,
            user_id: attrs.user_id,
            name: attrs.name,
            active_ingredient: attrs.active_ingredient,
            description: attrs.description,
            crop_id: attrs.crop_id,
            pest_id: attrs.pest_id,
            region: attrs.region,
            is_reference: attrs.is_reference,
            created_at: attrs.created_at,
            updated_at: attrs.updated_at,
        };
        entity.validate_region()?;
        Ok(entity)
    }

    pub fn reference(&self) -> bool {
        self.is_reference
    }

    fn validate_region(&self) -> Result<(), String> {
        if let Some(ref region) = self.region {
            if !VALID_REGIONS.contains(&region.as_str()) {
                return Err(format!(
                    "Region must be one of: {}",
                    VALID_REGIONS.join(", ")
                ));
            }
        }
        Ok(())
    }
}

impl RecordRef for PesticideEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[cfg(test)]
mod entities_pesticide_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pesticide/entities_pesticide_entity_test.rs"));
}
