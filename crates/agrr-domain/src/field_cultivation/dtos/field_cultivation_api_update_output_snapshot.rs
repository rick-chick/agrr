/// Gateway read shape before domain output mapping.
/// Ruby: `Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutputSnapshot`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationApiUpdateOutputSnapshot {
    pub field_cultivation_id: i64,
    pub start_date: String,
    pub completion_date: String,
    pub cultivation_days: Option<i32>,
}
