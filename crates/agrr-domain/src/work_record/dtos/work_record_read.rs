//! Ruby: `Domain::WorkRecord::Dtos::WorkRecordRead`

use rust_decimal::Decimal;
use time::{Date, OffsetDateTime};

/// Nested schedule item summary for API responses.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkRecordTaskScheduleItemSummary {
    pub id: i64,
    pub name: String,
    pub scheduled_date: Option<Date>,
}

/// Read model returned by gateways and output ports.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordRead {
    pub id: i64,
    pub cultivation_plan_id: i64,
    pub field_cultivation_id: Option<i64>,
    pub task_schedule_item_id: Option<i64>,
    pub agricultural_task_id: Option<i64>,
    pub name: String,
    pub task_type: Option<String>,
    pub actual_date: Date,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub time_spent_minutes: Option<i64>,
    pub notes: Option<String>,
    pub created_at: OffsetDateTime,
    pub updated_at: OffsetDateTime,
    pub field_name: Option<String>,
    pub crop_name: Option<String>,
    pub task_schedule_item: Option<WorkRecordTaskScheduleItemSummary>,
}
