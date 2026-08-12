//! Gateway for GDD and weather snapshot at work record actual_date.

use time::Date;

use crate::work_record::mappers::work_record_climate_snapshot_mapper::WorkRecordClimateSnapshot;

pub trait WorkRecordClimateSnapshotGateway: Send + Sync {
    fn snapshot_for_field_cultivation(
        &self,
        user_id: i64,
        field_cultivation_id: i64,
        actual_date: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
