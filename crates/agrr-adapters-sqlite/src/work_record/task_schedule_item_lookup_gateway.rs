//! Ruby: `TaskScheduleItemLookupActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::helpers::parse_iso_date;
use agrr_domain::work_record::gateways::{
    TaskScheduleItemLookupGateway, TaskScheduleItemPrefillSnapshot,
};
use rusqlite::params;
use rust_decimal::Decimal;
use std::str::FromStr;

pub struct TaskScheduleItemLookupSqliteGateway {
    pool: SqlitePool,
}

impl TaskScheduleItemLookupSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_snapshot(row: &rusqlite::Row<'_>) -> rusqlite::Result<TaskScheduleItemPrefillSnapshot> {
        let amount_raw: Option<String> = row.get(6)?;
        let amount = amount_raw.and_then(|s| Decimal::from_str(&s).ok());
        let scheduled_date_raw: Option<String> = row.get(5)?;
        Ok(TaskScheduleItemPrefillSnapshot {
            cultivation_plan_id: row.get(0)?,
            field_cultivation_id: row.get(1)?,
            agricultural_task_id: row.get(2)?,
            name: row.get(3)?,
            task_type: row.get(4)?,
            scheduled_date: scheduled_date_raw
                .as_deref()
                .and_then(parse_iso_date),
            amount,
            amount_unit: row.get(7)?,
        })
    }
}

impl TaskScheduleItemLookupGateway for TaskScheduleItemLookupSqliteGateway {
    fn find_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<TaskScheduleItemPrefillSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT ts.cultivation_plan_id, ts.field_cultivation_id, tsi.agricultural_task_id, \
                 tsi.name, tsi.task_type, tsi.scheduled_date, CAST(tsi.amount AS TEXT), tsi.amount_unit \
                 FROM task_schedule_items tsi \
                 INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                 WHERE ts.cultivation_plan_id = ?1 AND tsi.id = ?2 \
                 LIMIT 1",
                params![plan_id, item_id],
                Self::row_to_snapshot,
            )
        })
    }
}
