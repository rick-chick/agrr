//! Climate snapshot captured at work record actual_date.

use serde_json::Value;

/// GDD and weather row persisted on a work record.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordClimateSnapshot {
    pub gdd_at_actual: Option<f64>,
    pub weather_snapshot: Option<Value>,
}

impl WorkRecordClimateSnapshot {
    pub fn empty() -> Self {
        Self {
            gdd_at_actual: None,
            weather_snapshot: None,
        }
    }
}
