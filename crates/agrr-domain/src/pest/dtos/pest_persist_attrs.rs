use crate::shared::attr::{AttrMap, AttrValue};

const KEYS: &[&str] = &[
    "name",
    "name_scientific",
    "family",
    "order",
    "description",
    "occurrence_season",
    "region",
    "is_reference",
    "user_id",
    "source_pest_id",
    "pest_temperature_profile_attributes",
    "pest_thermal_requirement_attributes",
    "pest_control_methods_attributes",
];

/// Ruby: `Domain::Pest::Dtos::PestPersistAttrs`
#[derive(Debug, Clone)]
pub struct PestPersistAttrs {
    attributes: AttrMap,
}

impl PestPersistAttrs {
    pub fn from_normalized_hash(hash: AttrMap) -> Self {
        let mut attributes = AttrMap::new();
        for key in KEYS {
            if let Some(v) = hash.get(*key) {
                attributes.insert((*key).into(), v.clone());
            }
        }
        Self { attributes }
    }

    pub fn name(&self) -> Option<&AttrValue> {
        self.attributes.get("name")
    }

    pub fn user_id(&self) -> Option<&AttrValue> {
        self.attributes.get("user_id")
    }

    pub fn is_reference(&self) -> Option<&AttrValue> {
        self.attributes.get("is_reference")
    }

    pub fn to_ar_attributes(&self) -> AttrMap {
        self.attributes.clone()
    }
}

#[cfg(test)]
mod dtos_pest_persist_attrs_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/dtos_pest_persist_attrs_test.rs"));
}
