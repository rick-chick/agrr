//! Ruby: `Domain::WeatherData::OptimizationJobChainWeatherComputation`

use crate::shared::ports::ClockPort;
use crate::weather_data::policies::{
    WeatherDataFetchWindowPolicy, WeatherFetchRange, WeatherPredictionHorizonPolicy,
};
use time::Date;

/// Ruby: `Domain::WeatherData::OptimizationJobChainWeatherComputation`
pub struct OptimizationJobChainWeatherComputation;

impl OptimizationJobChainWeatherComputation {
    pub fn weather_window(
        latest_weather_date: Option<Date>,
        clock: &dyn ClockPort,
    ) -> WeatherFetchRange {
        WeatherDataFetchWindowPolicy::fetch_range(latest_weather_date, clock)
    }

    pub fn predict_days_to_next_year_end(end_date: Date, clock: &dyn ClockPort) -> i64 {
        WeatherPredictionHorizonPolicy::predict_days_to_next_year_end(end_date, clock)
    }
}

#[cfg(test)]
mod optimization_job_chain_weather_computation_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/optimization_job_chain_weather_computation_test.rs"));
}
