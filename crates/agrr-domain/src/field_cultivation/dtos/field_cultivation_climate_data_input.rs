#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationClimateDataInput {
    pub field_cultivation_id: i64,
    pub display_start_date: Option<String>,
    pub display_end_date: Option<String>,
}
