//! Work hub farm row for `/api/v1/work/hub`.

#[derive(Debug, Clone, PartialEq)]
pub struct WorkHubFarmRow {
    pub farm_id: i64,
    pub farm_name: String,
    pub field_count: i32,
    pub total_area: f64,
    pub has_valid_fields: bool,
    pub plan_id: Option<i64>,
}
