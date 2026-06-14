//! Ruby: `Domain::WorkRecord::Gateways::TaskScheduleItemLookupGateway`

use rust_decimal::Decimal;
use time::Date;

/// Raw schedule item attributes for prefill (gateway returns as-is; merge in interactor).
#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleItemPrefillSnapshot {
    pub cultivation_plan_id: i64,
    pub field_cultivation_id: Option<i64>,
    pub agricultural_task_id: Option<i64>,
    pub name: String,
    pub task_type: Option<String>,
    pub scheduled_date: Option<Date>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
}

pub trait TaskScheduleItemLookupGateway: Send + Sync {
    fn find_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<
        TaskScheduleItemPrefillSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    >;
}
