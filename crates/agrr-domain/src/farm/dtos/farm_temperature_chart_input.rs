//! Input for farm observed temperature chart read.

/// Request to load observed temperature chart data for a farm.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FarmTemperatureChartInput {
    pub farm_id: i64,
    pub user_id: i64,
    pub period: String,
}
