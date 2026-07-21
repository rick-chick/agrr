//! Output DTOs for farm observed temperature chart.

use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FarmTemperatureChartPoint {
    pub date: Date,
    pub temperature_min: Option<f64>,
    pub temperature_mean: Option<f64>,
    pub temperature_max: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FarmTemperatureChartDataQuality {
    pub expected_days: i64,
    pub present_days: i64,
    pub missing_days: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FarmTemperatureChartOutput {
    pub farm_id: i64,
    pub period: String,
    pub start_date: Date,
    pub end_date: Date,
    pub observed_only: bool,
    pub data_quality: FarmTemperatureChartDataQuality,
    pub points: Vec<FarmTemperatureChartPoint>,
}
