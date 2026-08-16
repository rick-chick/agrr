//! Read model for weather reschedule proposal adjust dry-run preview.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::weather_reschedule_proposal_read::WeatherRescheduleProposalRead;

/// Allocation snapshot slice returned in before/after preview diff.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WeatherRescheduleProposalAllocationSnapshot {
    pub field_schedules: Vec<Value>,
}

/// Before/after adjust dry-run preview for one weather reschedule proposal.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WeatherRescheduleProposalPreviewRead {
    pub proposal_id: String,
    pub proposal: WeatherRescheduleProposalRead,
    pub moves: Vec<Value>,
    pub before: WeatherRescheduleProposalAllocationSnapshot,
    pub after: WeatherRescheduleProposalAllocationSnapshot,
}
