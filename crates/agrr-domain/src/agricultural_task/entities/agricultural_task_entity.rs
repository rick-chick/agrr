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
mod tests {
    use super::*;

    fn base_attrs() -> AgriculturalTaskEntityAttrs {
        AgriculturalTaskEntityAttrs {
            id: Some(1),
            user_id: Some(1),
            name: "Test Task".into(),
            description: Some("Test description".into()),
            time_per_sqm: Some(0.5),
            weather_dependency: Some("sunny".into()),
            required_tools: vec!["tool1".into(), "tool2".into()],
            skill_level: Some("beginner".into()),
            region: Some("jp".into()),
            task_type: Some("planting".into()),
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = AgriculturalTaskEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name, "Test Task");
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil region"
    #[test]
    fn initializes_with_nil_region() {
        let mut attrs = base_attrs();
        attrs.region = None;
        let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
        assert!(entity.region.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn rejects_blank_name() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = AgriculturalTaskEntity::new(attrs).expect_err("invalid");
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "should raise error when region is invalid"
    #[test]
    fn rejects_invalid_region() {
        let mut attrs = base_attrs();
        attrs.region = Some("invalid".into());
        let err = AgriculturalTaskEntity::new(attrs).expect_err("invalid");
        assert_eq!(err, "Region must be one of: jp, us, in");
    }

    // Ruby: test "should accept valid regions jp, us, in"
    #[test]
    fn accepts_valid_regions() {
        for region in ["jp", "us", "in"] {
            let mut attrs = base_attrs();
            attrs.region = Some(region.into());
            let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
            assert_eq!(entity.region.as_deref(), Some(region));
        }
    }

    // Ruby: test "reference? should return true for reference tasks"
    #[test]
    fn reference_true_for_reference_tasks() {
        let entity = AgriculturalTaskEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }

    // Ruby: test "reference? should return false for non-reference tasks"
    #[test]
    fn reference_false_for_non_reference_tasks() {
        let mut attrs = base_attrs();
        attrs.is_reference = false;
        let entity = AgriculturalTaskEntity::new(attrs).expect("valid");
        assert!(!entity.reference());
    }
}
