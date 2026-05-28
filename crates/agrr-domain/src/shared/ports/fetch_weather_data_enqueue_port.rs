use crate::shared::dtos::WeatherFetchDateBlock;

/// Ruby: `Domain::Shared::Ports::FetchWeatherDataEnqueuePort`
pub trait FetchWeatherDataEnqueuePort: Send + Sync {
    fn enqueue_farm_weather_fetch(
        &self,
        farm_id: i64,
        latitude: f64,
        longitude: f64,
        blocks: &[WeatherFetchDateBlock],
    );
}
