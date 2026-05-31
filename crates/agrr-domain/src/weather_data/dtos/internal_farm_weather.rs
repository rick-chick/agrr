use serde_json::Value;

/// Ruby: `Domain::WeatherData::Dtos::InternalFarmWeatherReadInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InternalFarmWeatherReadInput {
    pub farm_id: String,
}

/// Ruby: `Domain::WeatherData::Dtos::InternalWeatherFetchFailure` (internal farm weather)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InternalFarmWeatherFetchFailure {
    pub message: String,
    pub http_status: InternalFarmWeatherHttpStatus,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InternalFarmWeatherHttpStatus {
    NotFound,
    InternalServerError,
}

/// Ruby: `Domain::WeatherData::Dtos::InternalFarmWeatherDataListOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct InternalFarmWeatherDataListOutput {
    pub farm_summary: Value,
    pub weather_location_summary: Value,
    pub weather_data_rows: Vec<Value>,
    pub count: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum InternalFarmWeatherDataListResult {
    FarmNotFound,
    WeatherLocationNotFound,
    StorageError,
    Ok(InternalFarmWeatherDataListOutput),
}

impl InternalFarmWeatherDataListResult {
    pub fn farm_not_found() -> Self {
        Self::FarmNotFound
    }

    pub fn weather_location_not_found() -> Self {
        Self::WeatherLocationNotFound
    }

    pub fn storage_error() -> Self {
        Self::StorageError
    }

    pub fn ok(success: InternalFarmWeatherDataListOutput) -> Self {
        Self::Ok(success)
    }
}

/// Ruby: `Domain::WeatherData::Dtos::InternalFarmWeatherStatusOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct InternalFarmWeatherStatusOutput {
    pub farm_id: i64,
    pub status: String,
    pub progress: i32,
    pub fetched_blocks: i32,
    pub total_blocks: i32,
    pub weather_data_count: i32,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum InternalFarmWeatherStatusResult {
    FarmNotFound,
    StorageError,
    Ok(InternalFarmWeatherStatusOutput),
}

impl InternalFarmWeatherStatusResult {
    pub fn farm_not_found() -> Self {
        Self::FarmNotFound
    }

    pub fn storage_error() -> Self {
        Self::StorageError
    }

    pub fn ok(success: InternalFarmWeatherStatusOutput) -> Self {
        Self::Ok(success)
    }
}
