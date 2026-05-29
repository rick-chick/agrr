//! Ruby: `Domain::CultivationPlan::Dtos::CropRowsAvailableRow`

#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct CropRowsAvailableRow {
    pub id: i64,
    pub name: String,
    pub variety: Option<String>,
    pub area_per_unit: Option<f64>,
}
