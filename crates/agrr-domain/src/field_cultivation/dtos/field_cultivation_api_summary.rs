use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationApiSummary {
    pub id: i64,
    pub field_name: String,
    pub crop_name: String,
    pub area: f64,
    pub start_date: Date,
    pub completion_date: Date,
    pub cultivation_days: i32,
    pub estimated_cost: f64,
    pub gdd: f64,
    pub status: String,
}
