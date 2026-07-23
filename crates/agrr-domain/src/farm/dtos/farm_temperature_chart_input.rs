/// Input for farm temperature chart read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FarmTemperatureChartInput {
    pub farm_id: i64,
    pub period: Option<String>,
}

impl FarmTemperatureChartInput {
    pub fn new(farm_id: i64, period: Option<String>) -> Self {
        Self { farm_id, period }
    }
}
