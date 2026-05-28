//! Farm weather progress ports used by fetch weather job interactors.

use crate::weather_data::dtos::FarmWeatherProgressSnapshot;

/// Ruby: `Domain::Farm::Interactors::MarkFarmWeatherDataFailedInteractor`
pub trait MarkFarmWeatherDataFailedPort: Send + Sync {
    fn call(&self, farm_id: i64, error_message: &str);
}

/// Ruby: `Domain::Farm::Interactors::RecordFarmWeatherBlockCompletedInteractor`
pub trait RecordFarmWeatherBlockCompletedPort: Send + Sync {
    fn call(
        &self,
        farm_id: i64,
        current_time: time::OffsetDateTime,
    ) -> Option<FarmWeatherProgressSnapshot>;
}

/// Ruby: cultivation plan phase advance (retry-on only).
pub trait AdvanceCultivationPlanPhasePort: Send + Sync {
    fn call_failed_fetching_weather(
        &self,
        plan_id: i64,
        channel_class: &str,
    );
}

/// Ruby: cultivation plan phase advance (perform interactor).
pub trait FetchWeatherAdvancePhasePort: Send + Sync {
    fn call(&self, plan_id: i64, phase: FetchWeatherPhase, channel_class: &str);
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FetchWeatherPhase {
    FetchingWeather,
    WeatherDataFetched,
}
