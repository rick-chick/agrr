//! Gateway: cumulative GDD and weather row for a field cultivation on a date.

use time::Date;

use crate::work_record::dtos::WorkRecordClimateSnapshot;

pub trait WorkRecordClimateSnapshotGateway: Send + Sync {
    fn lookup(
        &self,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
