//! Ruby: `Domain::WeatherData`

pub mod dtos;
pub mod optimization_job_chain_weather_computation;
pub mod gateways;
pub mod helpers;
pub mod interactors;
pub mod mappers;
pub mod policies;
pub mod ports;

pub use dtos::*;
pub use interactors::*;
pub use mappers::{AdjustHistoricalPredictionMapper, OpenMeteoWeatherMapper};
pub use optimization_job_chain_weather_computation::OptimizationJobChainWeatherComputation;
pub use policies::{
    SchedulerReferenceFarmFetchWindowPolicy, SchedulerReferenceFetchRange,
    SchedulerUserFarmFetchWindowPolicy, SchedulerUserFetchRange,
    WeatherDataFetchWindowPolicy, WeatherFetchRange, WeatherPredictionHorizonPolicy,
    SCHEDULER_REFERENCE_WEATHER_LOOKBACK_DAYS, SCHEDULER_USER_WEATHER_DEFAULT_LOOKBACK_DAYS,
};
