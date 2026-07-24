use crate::internal_jobs::dtos::SchedulerWeatherFarmRow;

/// Narrow read for scheduler weather update jobs (Rails `Update*WeatherDataJob` scopes).
pub trait SchedulerWeatherFarmListGateway: Send + Sync {
    /// `Farm.reference` with non-null latitude/longitude.
    fn list_reference_farms_for_weather_update(
        &self,
    ) -> Result<Vec<SchedulerWeatherFarmRow>, String>;

    /// `Farm.user_owned` with `weather_location_id` set.
    fn list_user_farms_for_weather_update(&self) -> Result<Vec<SchedulerWeatherFarmRow>, String>;

    /// User-owned farms with coordinates still awaiting initial full history fetch.
    fn list_user_farms_pending_initial_weather_fetch(&self) -> Result<Vec<i64>, String>;
}
