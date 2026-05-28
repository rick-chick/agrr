//! Ruby: `Domain::Crop::Dtos::AddCropCropSnapshot`

#[derive(Debug, Clone, PartialEq)]
pub struct AddCropCropSnapshot {
    pub id: i64,
    pub name: String,
    pub variety: Option<String>,
    pub area_per_unit: f64,
    pub revenue_per_area: f64,
}
