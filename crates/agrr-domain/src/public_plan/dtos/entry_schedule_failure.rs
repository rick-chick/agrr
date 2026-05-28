//! Ruby: `Domain::PublicPlan::Dtos::EntryScheduleFailure`

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntryScheduleFailureKind {
    RecordNotFound,
    WeatherLocationRequired,
    PredictionPayloadMissing,
    WeatherPredictionFailed,
    InternalError,
}

/// Ruby: `Domain::PublicPlan::Dtos::EntryScheduleFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EntryScheduleFailure {
    pub kind: EntryScheduleFailureKind,
    pub detail_message: Option<String>,
}

impl EntryScheduleFailure {
    pub fn record_not_found(message: impl Into<String>) -> Self {
        Self {
            kind: EntryScheduleFailureKind::RecordNotFound,
            detail_message: Some(message.into()),
        }
    }

    pub fn weather_location_required() -> Self {
        Self {
            kind: EntryScheduleFailureKind::WeatherLocationRequired,
            detail_message: None,
        }
    }

    pub fn prediction_payload_missing() -> Self {
        Self {
            kind: EntryScheduleFailureKind::PredictionPayloadMissing,
            detail_message: None,
        }
    }

    pub fn weather_prediction_failed(message: impl Into<String>) -> Self {
        Self {
            kind: EntryScheduleFailureKind::WeatherPredictionFailed,
            detail_message: Some(message.into()),
        }
    }

    pub fn internal_error(message: impl Into<String>) -> Self {
        Self {
            kind: EntryScheduleFailureKind::InternalError,
            detail_message: Some(message.into()),
        }
    }
}
