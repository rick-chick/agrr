use crate::shared::record_ref::RecordRef;

/// Ruby: `Domain::Crop::Entities::CropEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct CropEntity {
    pub id: i64,
    pub user_id: Option<i64>,
    pub name: String,
    pub variety: Option<String>,
    pub is_reference: bool,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
    pub region: Option<String>,
    pub groups: Vec<String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl CropEntity {
    pub fn new(
        id: i64,
        name: impl Into<String>,
        user_id: Option<i64>,
        is_reference: bool,
    ) -> Result<Self, String> {
        let name = name.into();
        if name.trim().is_empty() {
            return Err("Name is required".into());
        }
        Ok(Self {
            id,
            user_id,
            name,
            variety: None,
            is_reference,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        })
    }

    pub fn reference(&self) -> bool {
        self.is_reference
    }

    pub fn display_name(&self) -> String {
        match &self.variety {
            Some(v) if !v.is_empty() => format!("{} {}", self.name, v),
            _ => self.name.clone(),
        }
    }
}

impl RecordRef for CropEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}
