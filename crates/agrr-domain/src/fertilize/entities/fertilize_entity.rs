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
mod tests {
    use super::*;

    fn base_attrs() -> FertilizeEntityAttrs {
        FertilizeEntityAttrs {
            id: Some(1),
            user_id: None,
            name: "尿素".into(),
            n: Some(46.0),
            p: None,
            k: None,
            description: Some("窒素肥料".into()),
            package_size: Some(25.0),
            region: None,
            is_reference: true,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        }
    }

    // Ruby: test "should initialize with valid attributes"
    #[test]
    fn initializes_with_valid_attributes() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name, "尿素");
        assert_eq!(entity.n, Some(46.0));
        assert!(entity.reference());
    }

    // Ruby: test "should initialize with nil package_size"
    #[test]
    fn initializes_with_nil_package_size() {
        let mut attrs = base_attrs();
        attrs.package_size = None;
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert!(entity.package_size.is_none());
    }

    // Ruby: test "should raise error when name is blank"
    #[test]
    fn raises_when_name_blank() {
        let mut attrs = base_attrs();
        attrs.name = String::new();
        let err = FertilizeEntity::new(attrs).unwrap_err();
        assert_eq!(err, "Name is required");
    }

    // Ruby: test "has_nutrient? should return true when nutrient is present and > 0"
    #[test]
    fn has_nutrient_returns_true_when_present() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert!(entity.has_nutrient("n"));
        assert!(!entity.has_nutrient("p"));
        assert!(!entity.has_nutrient("k"));
    }

    // Ruby: test "npk_summary should return formatted string"
    #[test]
    fn npk_summary_formatted() {
        let mut attrs = base_attrs();
        attrs.n = Some(20.0);
        attrs.p = Some(10.0);
        attrs.k = Some(5.0);
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert_eq!(entity.npk_summary(), "20-10-5");
    }

    // Ruby: test "npk_summary should handle nil values"
    #[test]
    fn npk_summary_handles_nil_values() {
        let mut attrs = base_attrs();
        attrs.n = Some(20.0);
        attrs.p = None;
        attrs.k = Some(10.0);
        let entity = FertilizeEntity::new(attrs).expect("valid");
        assert_eq!(entity.npk_summary(), "20-10");
    }

    // Ruby: test "reference? should return true for reference fertilizes"
    #[test]
    fn reference_returns_true_for_reference() {
        let entity = FertilizeEntity::new(base_attrs()).expect("valid");
        assert!(entity.reference());
    }
}
