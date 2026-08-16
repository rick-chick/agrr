//! Read model for proactive weather-triggered reschedule proposals.

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Trigger kinds classified by `WeatherRescheduleTriggerPolicy` (#1050).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WeatherRescheduleTriggerType {
    FrostForecast,
    GddTrajectoryDelay,
    ForecastSuddenChange,
}

/// One weather-triggered adjust proposal returned by `GET .../weather_reschedule_proposals`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WeatherRescheduleProposalRead {
    pub id: String,
    pub trigger_type: WeatherRescheduleTriggerType,
    pub severity: String,
    pub rationale: Value,
    pub moves: Vec<Value>,
}
