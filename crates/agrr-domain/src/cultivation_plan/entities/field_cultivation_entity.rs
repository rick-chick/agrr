//! Ruby: `Domain::CultivationPlan::Entities::FieldCultivationEntity`

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationEntity {
    pub id: i64,
    pub cultivation_plan_id: i64,
    pub cultivation_plan_field_id: Option<i64>,
    pub cultivation_plan_crop_id: Option<i64>,
    pub area: Option<f64>,
    pub status: Option<String>,
}
