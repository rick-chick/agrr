use super::FieldCultivationSyncFieldScheduleInput;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncInput {
    pub field_schedules: Vec<FieldCultivationSyncFieldScheduleInput>,
    pub optimization_summary: Option<String>,
    pub total_profit: Option<f64>,
    pub total_revenue: Option<f64>,
    pub total_cost: Option<f64>,
    pub optimization_time: Option<f64>,
    pub algorithm_used: Option<String>,
    pub is_optimal: Option<bool>,
}
