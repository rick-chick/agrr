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
mod tests {
    use super::*;

    fn base_attrs() -> PesticideEntityAttrs {
        PesticideEntityAttrs {
            id: 1,
            user_id: Some(2),
            name: "Test Pesticide".into(),
            active_ingredient: Some("Test Ingredient".into()),
            description: Some("Test Description".into()),
            crop_id: Some(3),
            pest_id: Some(4),
            region: Some("jp".into()),
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = PesticideEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, 1);
        assert_eq!(entity.user_id, Some(2));
        assert_eq!(entity.name, "Test Pesticide");
        assert_eq!(entity.active_ingredient.as_deref(), Some("Test Ingredient"));
        assert_eq!(entity.description.as_deref(), Some("Test Description"));
        assert_eq!(entity.crop_id, Some(3));
        assert_eq!(entity.pest_id, Some(4));
        assert_eq!(entity.region.as_deref(), Some("jp"));
        assert!(!entity.is_reference);
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = PesticideEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn raises_when_region_invalid() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = PesticideEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should initialize with valid regions"
    #[test]
    fn initializes_with_valid_regions() {
        for valid_region in VALID_REGIONS {
            let mut attrs = base_attrs();
            attrs.region = Some(valid_region.into());
            let entity = PesticideEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(valid_region));
        }
    }
}
