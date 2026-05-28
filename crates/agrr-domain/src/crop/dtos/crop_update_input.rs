#[derive(Debug, Clone, PartialEq)]
pub struct CropUpdateInput {
    pub crop_id: i64,
    pub name: Option<String>,
    pub variety: Option<String>,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
    pub region: Option<String>,
    pub groups: Option<Vec<String>>,
    pub is_reference: Option<bool>,
}

impl CropUpdateInput {
    pub fn new(crop_id: i64) -> Self {
        Self { crop_id, name: None, variety: None, area_per_unit: None, revenue_per_area: None, region: None, groups: None, is_reference: None }
    }
}
