use time::Date;

/// Farm row for scheduler weather batch enqueue (narrow read).
#[derive(Debug, Clone, PartialEq)]
pub struct SchedulerWeatherFarmRow {
    pub farm_id: i64,
    pub latitude: f64,
    pub longitude: f64,
    /// Set for user-owned farms (`UpdateUserFarmsWeatherDataJob`); `None` for reference farms.
    pub latest_weather_date: Option<Date>,
}
