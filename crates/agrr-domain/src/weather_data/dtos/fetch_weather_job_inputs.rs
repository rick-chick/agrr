//! Fetch weather job input DTOs.

use time::{Date, OffsetDateTime};

/// Ruby: perform job input hash
#[derive(Debug, Clone)]
pub struct FetchWeatherDataPerformInput {
    pub latitude: f64,
    pub longitude: f64,
    pub start_date: Date,
    pub end_date: Date,
    pub farm_id: Option<i64>,
    pub cultivation_plan_id: Option<i64>,
    pub channel_class: Option<String>,
    pub executions: i32,
    pub current_time: OffsetDateTime,
}

/// Ruby: discard-on job input hash
#[derive(Debug, Clone)]
pub struct FetchWeatherDataDiscardOnInput {
    pub farm_id: Option<i64>,
    pub start_date: Date,
    pub end_date: Date,
    pub error_message: String,
}

/// Ruby: retry-on job input hash
#[derive(Debug, Clone)]
pub struct FetchWeatherDataRetryOnInput {
    pub farm_id: Option<i64>,
    pub start_date: Date,
    pub end_date: Date,
    pub executions: i32,
    pub error_message: String,
    pub cultivation_plan_id: Option<i64>,
    pub channel_class: Option<String>,
}

/// Updated farm snapshot after recording weather block progress.
#[derive(Debug, Clone)]
pub struct FarmWeatherProgressSnapshot {
    pub weather_data_progress: i32,
    pub weather_data_fetched_years: i32,
    pub weather_data_total_years: i32,
}
