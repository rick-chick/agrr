/// Ruby: `Domain::Crop::Dtos::CropCreateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct CropCreateInput {
    pub name: String,
    pub variety: Option<String>,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
    pub region: Option<String>,
    pub groups: Vec<String>,
    pub is_reference: bool,
}

impl CropCreateInput {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            is_reference: false,
        }
    }
}
