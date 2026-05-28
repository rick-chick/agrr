use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncAllocationInput {
    pub allocation_id: Option<i64>,
    pub external_allocation_id: Option<String>,
    pub crop_id: String,
    pub start_date: Date,
    pub completion_date: Date,
    pub area_used: Option<f64>,
    pub area: Option<f64>,
    pub total_cost: Option<f64>,
    pub cost: Option<f64>,
    pub expected_revenue: Option<f64>,
    pub revenue: Option<f64>,
    pub profit: Option<f64>,
    pub accumulated_gdd: Option<f64>,
}

impl FieldCultivationSyncAllocationInput {
    pub fn resolved_allocation_raw(&self) -> Option<String> {
        if let Some(id) = self.allocation_id {
            Some(id.to_string())
        } else {
            self.external_allocation_id.clone()
        }
    }
}
