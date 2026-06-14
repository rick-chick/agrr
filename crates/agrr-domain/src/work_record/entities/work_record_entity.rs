//! Ruby: `Domain::WorkRecord::Entities::WorkRecordEntity`

use rust_decimal::Decimal;
use time::{Date, OffsetDateTime};

/// Ruby: `Domain::WorkRecord::Entities::WorkRecordEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordEntity {
    pub id: Option<i64>,
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
}

impl WorkRecordEntity {
    pub fn validate_name(name: &str) -> Result<(), String> {
        if name.trim().is_empty() {
            return Err("name is required".into());
        }
        Ok(())
    }
}
