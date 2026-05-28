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
mod tests {
    use super::*;
    use crate::shared::attr::attr_map_from_pairs;

    // Ruby: test "from_normalized_hash keeps only known keys and exposes readers"
    #[test]
    fn from_normalized_hash_keeps_only_known_keys() {
        let dto = PestPersistAttrs::from_normalized_hash(attr_map_from_pairs([
            ("name", AttrValue::from("アブラムシ")),
            ("user_id", AttrValue::Int(9)),
            ("is_reference", AttrValue::Bool(false)),
            ("ignored_extra", AttrValue::from("x")),
        ]));
        assert_eq!(
            dto.name().and_then(|v| v.as_str()),
            Some("アブラムシ")
        );
        assert_eq!(dto.user_id(), Some(&AttrValue::Int(9)));
        assert_eq!(dto.is_reference(), Some(&AttrValue::Bool(false)));
        assert!(!dto.to_ar_attributes().contains_key("ignored_extra"));
    }

    // Ruby: test "to_ar_attributes returns mutable dup"
    #[test]
    fn to_ar_attributes_returns_mutable_dup() {
        let dto = PestPersistAttrs::from_normalized_hash(attr_map_from_pairs([
            ("name", AttrValue::from("x")),
            ("user_id", AttrValue::Int(1)),
            ("is_reference", AttrValue::Bool(false)),
        ]));
        let mut h = dto.to_ar_attributes();
        h.insert("name".into(), AttrValue::from("y"));
        assert_eq!(
            dto.name().and_then(|v| v.as_str()),
            Some("x")
        );
    }
}
