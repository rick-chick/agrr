//! Climate snapshot capture for work records at actual_date.

use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordClimateSnapshot {
    pub gdd_at_actual: Option<f64>,
    pub weather_snapshot: Option<Value>,
}

pub trait WorkRecordClimateSnapshotGateway: Send + Sync {
    fn capture_at_date(
        &self,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<Option<WorkRecordClimateSnapshot>, Box<dyn std::error::Error + Send + Sync>>;
}
