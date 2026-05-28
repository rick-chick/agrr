use time::Date;

pub fn missing_weather_location(weather_location_id: Option<i64>) -> bool {
    weather_location_id.is_none()
}

pub fn missing_cultivation_period(
    start_date: Option<Date>,
    completion_date: Option<Date>,
) -> bool {
    start_date.is_none() || completion_date.is_none()
}
