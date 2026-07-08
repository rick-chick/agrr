//! Ruby: `TaskScheduleItemMutationActiveRecordGateway` — skip/unskip slice (P5).

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::constants::task_schedule_item_statuses::{PLANNED, SKIPPED};
use agrr_domain::cultivation_plan::dtos::{
    TaskScheduleAgriculturalTaskSnapshot, TaskScheduleFieldCultivationSnapshot,
    TaskScheduleItemAmountSnapshot, TaskScheduleItemDeletionUndoScheduleRow,
};
use agrr_domain::cultivation_plan::gateways::TaskScheduleItemMutationGateway;
use agrr_domain::shared::attr::AttrMap;
use rusqlite::params;
use serde_json::{json, Value};
use time::{format_description::well_known::Iso8601, OffsetDateTime};

pub struct TaskScheduleItemMutationSqliteGateway {
    pool: SqlitePool,
}

impl TaskScheduleItemMutationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn format_datetime(dt: OffsetDateTime) -> String {
        dt.format(&Iso8601::DEFAULT)
            .unwrap_or_else(|_| dt.unix_timestamp().to_string())
    }

    fn item_belongs_to_plan(conn: &rusqlite::Connection, plan_id: i64, item_id: i64) -> rusqlite::Result<bool> {
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM task_schedule_items tsi \
             INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
             WHERE ts.cultivation_plan_id = ?1 AND tsi.id = ?2",
            params![plan_id, item_id],
            |row| row.get(0),
        )?;
        Ok(count > 0)
    }
}

impl TaskScheduleItemMutationGateway for TaskScheduleItemMutationSqliteGateway {
    fn find_field_cultivation_for_create(
        &self,
        _plan_id: i64,
        _field_cultivation_id: i64,
    ) -> Result<TaskScheduleFieldCultivationSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Err("not implemented".into())
    }

    fn find_agricultural_task_for_mutation(
        &self,
        _agricultural_task_id: Option<i64>,
    ) -> Result<Option<TaskScheduleAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        Err("not implemented".into())
    }

    fn find_item_amount_snapshot(
        &self,
        _plan_id: i64,
        _item_id: i64,
    ) -> Result<TaskScheduleItemAmountSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Err("not implemented".into())
    }

    fn create(
        &self,
        _plan_id: i64,
        _attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        Err("not implemented".into())
    }

    fn update_item_for_plan(
        &self,
        _plan_id: i64,
        _item_id: i64,
        _attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        Err("not implemented".into())
    }

    fn skip_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
        cancelled_at: OffsetDateTime,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let cancelled_at_str = Self::format_datetime(cancelled_at);
        self.pool.with_write_box(|conn| {
            if !Self::item_belongs_to_plan(conn, plan_id, item_id)? {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            let updated = conn.execute(
                "UPDATE task_schedule_items SET status = ?1, cancelled_at = ?2, updated_at = ?2 \
                 WHERE id = ?3",
                params![SKIPPED, cancelled_at_str, item_id],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(json!({
                "id": item_id,
                "status": SKIPPED,
                "cancelled_at": cancelled_at_str,
            }))
        })
    }

    fn unskip_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            if !Self::item_belongs_to_plan(conn, plan_id, item_id)? {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            let updated = conn.execute(
                "UPDATE task_schedule_items SET status = ?1, cancelled_at = NULL, updated_at = datetime('now') \
                 WHERE id = ?2",
                params![PLANNED, item_id],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(json!({
                "id": item_id,
                "status": PLANNED,
                "cancelled_at": null,
            }))
        })
    }

    fn deletion_undo_schedule_row_for_item(
        &self,
        _plan_id: i64,
        _item_id: i64,
    ) -> Result<TaskScheduleItemDeletionUndoScheduleRow, Box<dyn std::error::Error + Send + Sync>> {
        Err("not implemented".into())
    }
}
