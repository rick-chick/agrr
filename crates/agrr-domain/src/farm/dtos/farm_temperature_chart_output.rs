use time::Date;

/// One observed daily temperature point for the farm chart.
#[derive(Debug, Clone, PartialEq)]
pub struct FarmTemperatureChartPoint {
    pub date: Date,
    pub temperature_min: Option<f64>,
    pub temperature_mean: Option<f64>,
    pub temperature_max: Option<f64>,
}

/// Data quality summary for the requested period.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FarmTemperatureChartDataQuality {
    pub expected_days: i64,
    pub present_days: i64,
    pub missing_days: i64,
}

/// Successful farm temperature chart payload.
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
