use time::Date;

/// Observed daily weather row for climate payload mappers.
#[derive(Debug, Clone, PartialEq)]
pub struct ClimateObservedWeatherDatum {
    pub date: Date,
    pub temperature_max: Option<f64>,
    pub temperature_min: Option<f64>,
    pub temperature_mean: Option<f64>,
    pub precipitation: Option<f64>,
    pub sunshine_hours: Option<f64>,
    pub wind_speed: Option<f64>,
    pub weather_code: Option<i32>,
}
