//! Internal weather fetch DTOs.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InternalWeatherFetchHttpStatus {
    NotFound,
    InternalServerError,
}

/// Ruby: `Domain::WeatherData::Dtos::InternalWeatherFetchStartInput`
#[derive(Debug, Clone)]
pub struct InternalWeatherFetchStartInput {
    pub farm_id: String,
}

/// Ruby: `Domain::WeatherData::Dtos::InternalWeatherFetchStartOutput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InternalWeatherFetchStartOutput {
    pub variant: InternalWeatherFetchStartVariant,
    pub farm_id: i64,
    pub weather_data_status: String,
    pub weather_data_count: Option<i32>,
    pub total_blocks: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InternalWeatherFetchStartVariant {
    AlreadyCompleted,
    FetchStarted,
}

/// Ruby: `Domain::WeatherData::Dtos::InternalWeatherFetchFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InternalWeatherFetchFailure {
    pub message: String,
    pub http_status: InternalWeatherFetchHttpStatus,
}

/// Ruby: `Domain::WeatherData::Dtos::WeatherPredictionAnchors`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WeatherPredictionAnchors {
    pub training_start_date: time::Date,
    pub training_end_date: time::Date,
    pub current_year_history_start_date: time::Date,
    pub current_year_history_end_date: time::Date,
    pub default_target_end_date: time::Date,
}
