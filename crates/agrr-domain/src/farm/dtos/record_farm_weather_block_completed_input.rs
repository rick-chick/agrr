/// Ruby: `Domain::Farm::Dtos::RecordFarmWeatherBlockCompletedInput`
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RecordFarmWeatherBlockCompletedInput {
    pub farm_id: i64,
    /// Unix timestamp (seconds) for throttle / last_broadcast_at.
    pub current_time: f64,
}
