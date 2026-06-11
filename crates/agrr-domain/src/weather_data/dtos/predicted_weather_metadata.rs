//! Metadata for predicted weather cache (payload lives in GCS).

use time::Date;

/// Scope for predicted weather storage (`predicted_weather/{scope}/{id}.json`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PredictedWeatherScope {
    Location,
    Plan,
}

impl PredictedWeatherScope {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Location => "location",
            Self::Plan => "plan",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "location" => Some(Self::Location),
            "plan" => Some(Self::Plan),
            _ => None,
        }
    }
}

/// SQLite row for cache-hit checks without loading GCS payload.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PredictedWeatherMetadata {
    pub scope: PredictedWeatherScope,
    pub scope_id: i64,
    pub prediction_start_date: Date,
    pub prediction_end_date: Date,
    pub target_end_date: Date,
    pub data_end_date: Date,
    pub generated_at: String,
}

impl PredictedWeatherMetadata {
    pub fn covers_target(&self, target_end_date: Date) -> bool {
        self.prediction_end_date >= target_end_date && self.data_end_date >= target_end_date
    }
}
