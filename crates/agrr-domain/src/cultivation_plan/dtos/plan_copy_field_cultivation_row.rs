//! Ruby: plan copy field cultivation row.

#[derive(Debug, Clone, PartialEq)]
pub struct PlanCopyFieldCultivationRow {
    pub id: i64,
    pub cultivation_plan_field_id: i64,
    pub cultivation_plan_crop_id: i64,
    pub area: f64,
    pub status: String,
}
