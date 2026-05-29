use crate::shared::hash::blank_attr;
use crate::shared::record_ref::RecordRef;

/// Ruby: `Domain::Fertilize::Entities::FertilizeEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct FertilizeEntity {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub name: String,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct FertilizeEntityAttrs {
    pub id: Option<i64>,
    pub user_id: Option<i64>,
    pub name: String,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub region: Option<String>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl FertilizeEntity {
    pub fn new(attrs: FertilizeEntityAttrs) -> Result<Self, String> {
        let entity = Self {
            id: attrs.id,
            user_id: attrs.user_id,
            name: attrs.name,
            n: attrs.n,
            p: attrs.p,
            k: attrs.k,
            description: attrs.description,
            package_size: attrs.package_size,
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

    pub fn has_nutrient(&self, nutrient: &str) -> bool {
        match nutrient {
            "n" => self.n.map(|v| v > 0.0).unwrap_or(false),
            "p" => self.p.map(|v| v > 0.0).unwrap_or(false),
            "k" => self.k.map(|v| v > 0.0).unwrap_or(false),
            _ => false,
        }
    }

    pub fn npk_summary(&self) -> String {
        [self.n, self.p, self.k]
            .into_iter()
            .flatten()
            .map(|v| v.trunc() as i64)
            .map(|v| v.to_string())
            .collect::<Vec<_>>()
            .join("-")
    }

    fn validate(&self) -> Result<(), String> {
        if blank_attr(&crate::shared::attr::AttrValue::Str(self.name.clone())) {
            return Err("Name is required".into());
        }
        Ok(())
    }
}

impl RecordRef for FertilizeEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[cfg(test)]
mod entities_fertilize_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/fertilize/entities_fertilize_entity_test.rs"));
}
