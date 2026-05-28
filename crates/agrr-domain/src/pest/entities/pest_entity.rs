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
mod tests {
    use super::*;

    fn base_attrs() -> PestEntityAttrs {
        PestEntityAttrs {
            id: Some(1),
            user_id: Some(123),
            name: "Test Pest".into(),
            name_scientific: Some("Testus pestus".into()),
            family: Some("Testidae".into()),
            order: Some("Testales".into()),
            description: Some("A test pest".into()),
            occurrence_season: Some("Spring".into()),
            region: Some("jp".into()),
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, 1);
        assert_eq!(entity.user_id, Some(123));
        assert_eq!(entity.name, "Test Pest");
        assert_eq!(entity.name_scientific.as_deref(), Some("Testus pestus"));
        assert_eq!(entity.family.as_deref(), Some("Testidae"));
        assert_eq!(entity.order.as_deref(), Some("Testales"));
        assert_eq!(entity.description.as_deref(), Some("A test pest"));
        assert_eq!(entity.occurrence_season.as_deref(), Some("Spring"));
        assert_eq!(entity.region.as_deref(), Some("jp"));
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = PestEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn raises_when_name_blank() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = PestEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn raises_when_region_invalid() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = PestEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should accept valid regions"
    #[test]
    fn accepts_valid_regions() {
        for region in ["jp", "us", "in"] {
            let mut attrs = base_attrs();
            attrs.region = Some(region.into());
            let entity = PestEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(region));
        }
    }

    // Ruby: test "reference? returns true when is_reference is true"
    #[test]
    fn reference_true_when_is_reference_true() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }

    // Ruby: test "reference? returns false when is_reference is false"
    #[test]
    fn reference_false_when_is_reference_false() {
        let mut attrs = base_attrs();
        attrs.is_reference = false;
        let entity = PestEntity::new(attrs).expect("valid");
        assert!(!entity.reference());
    }

    // Ruby: test "to_hash returns expected hash"
    #[test]
    fn to_hash_returns_expected_fields() {
        let entity = PestEntity::new(base_attrs()).expect("valid");
        let h = entity.to_hash();
        assert_eq!(h.get("id"), Some(&serde_json::json!(1)));
        assert_eq!(h.get("name"), Some(&serde_json::json!("Test Pest")));
        assert_eq!(h.get("is_reference"), Some(&serde_json::json!(true)));
        assert!(!h.contains_key("region"));
        assert!(!h.contains_key("user_id"));
    }
}
