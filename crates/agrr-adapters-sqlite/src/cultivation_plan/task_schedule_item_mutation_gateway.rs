//! Ruby: `TaskScheduleItemMutationActiveRecordGateway` — skip/unskip + create/update (P5/P867).

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::constants::task_schedule_item_statuses::{PLANNED, SKIPPED};
use agrr_domain::cultivation_plan::dtos::{
    TaskScheduleAgriculturalTaskSnapshot, TaskScheduleFieldCultivationSnapshot,
    TaskScheduleItemAmountSnapshot, TaskScheduleItemDeletionUndoScheduleRow,
};
use agrr_domain::cultivation_plan::gateways::TaskScheduleItemMutationGateway;
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::exceptions::RecordNotFoundError;
use rusqlite::{params, OptionalExtension};
use rust_decimal::Decimal;
use serde_json::{json, Value};
use std::str::FromStr;
use time::{format_description::well_known::Iso8601, Date, Month, OffsetDateTime};

const DEFAULT_CATEGORY: &str = "general";

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

    fn attr_str(attrs: &AttrMap, key: &str) -> Option<String> {
        match attrs.get(key) {
            Some(AttrValue::Str(s)) if !s.trim().is_empty() => Some(s.clone()),
            Some(AttrValue::Int(i)) => Some(i.to_string()),
            _ => None,
        }
    }

    fn attr_i64(attrs: &AttrMap, key: &str) -> Option<i64> {
        match attrs.get(key) {
            Some(AttrValue::Int(i)) => Some(*i),
            Some(AttrValue::Str(s)) => s.parse().ok(),
            _ => None,
        }
    }

    fn attr_i32(attrs: &AttrMap, key: &str) -> Option<i32> {
        Self::attr_i64(attrs, key).and_then(|v| i32::try_from(v).ok())
    }

    fn attr_decimal(attrs: &AttrMap, key: &str) -> Option<Decimal> {
        Self::attr_str(attrs, key).and_then(|s| Decimal::from_str(&s).ok())
    }

    fn parse_date(raw: &str) -> Option<Date> {
        let parts: Vec<&str> = raw.split('-').collect();
        if parts.len() != 3 {
            return None;
        }
        let year: i32 = parts[0].parse().ok()?;
        let month = Month::try_from(parts[1].parse::<u8>().ok()?).ok()?;
        let day: u8 = parts[2].parse().ok()?;
        Date::from_calendar_date(year, month, day).ok()
    }

    fn find_or_create_schedule_id(
        conn: &rusqlite::Connection,
        plan_id: i64,
        field_cultivation_id: i64,
    ) -> rusqlite::Result<i64> {
        if let Some(id) = conn
            .query_row(
                "SELECT id FROM task_schedules \
                 WHERE cultivation_plan_id = ?1 AND field_cultivation_id = ?2 AND category = ?3 \
                 LIMIT 1",
                params![plan_id, field_cultivation_id, DEFAULT_CATEGORY],
                |row| row.get(0),
            )
            .optional()?
        {
            return Ok(id);
        }
        conn.execute(
            "INSERT INTO task_schedules (cultivation_plan_id, field_cultivation_id, category, \
             status, source, generated_at, created_at, updated_at) \
             VALUES (?1, ?2, ?3, 'active', 'manual', datetime('now'), datetime('now'), datetime('now'))",
            params![plan_id, field_cultivation_id, DEFAULT_CATEGORY],
        )?;
        Ok(conn.last_insert_rowid())
    }

    fn item_json_from_row(
        id: i64,
        name: String,
        task_type: String,
        scheduled_date: Option<String>,
        status: String,
        source: String,
        agricultural_task_id: Option<i64>,
        rescheduled_at: Option<String>,
        cancelled_at: Option<String>,
    ) -> Value {
        json!({
            "id": id,
            "name": name,
            "task_type": task_type,
            "scheduled_date": scheduled_date,
            "status": status,
            "source": source,
            "agricultural_task_id": agricultural_task_id,
            "rescheduled_at": rescheduled_at,
            "cancelled_at": cancelled_at,
        })
    }
}

impl TaskScheduleItemMutationGateway for TaskScheduleItemMutationSqliteGateway {
    fn find_field_cultivation_for_create(
        &self,
        plan_id: i64,
        field_cultivation_id: i64,
    ) -> Result<TaskScheduleFieldCultivationSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT fc.id, fc.cultivation_plan_crop_id, cpc.crop_id \
                 FROM field_cultivations fc \
                 INNER JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
                 WHERE fc.cultivation_plan_id = ?1 AND fc.id = ?2",
                params![plan_id, field_cultivation_id],
                |row| {
                    Ok(TaskScheduleFieldCultivationSnapshot {
                        id: row.get(0)?,
                        cultivation_plan_crop_id: row.get(1)?,
                        crop_id: row.get(2)?,
                    })
                },
            )
        })
    }

    fn find_agricultural_task_for_mutation(
        &self,
        agricultural_task_id: Option<i64>,
    ) -> Result<Option<TaskScheduleAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        let Some(task_id) = agricultural_task_id else {
            return Ok(None);
        };
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, description, task_type, weather_dependency, time_per_sqm \
                 FROM agricultural_tasks WHERE id = ?1",
                params![task_id],
                |row| {
                    let time_per_sqm: Option<f64> = row.get(5)?;
                    Ok(TaskScheduleAgriculturalTaskSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        description: row.get(2)?,
                        task_type: row.get(3)?,
                        weather_dependency: row.get(4)?,
                        time_per_sqm: time_per_sqm
                            .and_then(|v| Decimal::from_str(&v.to_string()).ok()),
                    })
                },
            )
            .optional()
        })
    }

    fn find_item_amount_snapshot(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<TaskScheduleItemAmountSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT tsi.amount, tsi.amount_unit, tsi.scheduled_date \
                 FROM task_schedule_items tsi \
                 INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                 WHERE ts.cultivation_plan_id = ?1 AND tsi.id = ?2",
                params![plan_id, item_id],
                |row| {
                    let amount: Option<f64> = row.get(0)?;
                    let amount_unit: Option<String> = row.get(1)?;
                    let scheduled_date_raw: Option<String> = row.get(2)?;
                    let scheduled_date = scheduled_date_raw
                        .as_deref()
                        .and_then(Self::parse_date)
                        .unwrap_or_else(|| {
                            Date::from_calendar_date(1970, Month::January, 1).expect("epoch")
                        });
                    Ok(TaskScheduleItemAmountSnapshot {
                        amount: amount
                            .and_then(|v| Decimal::from_str(&v.to_string()).ok()),
                        amount_unit,
                        scheduled_date,
                    })
                },
            )
        })
    }

    fn create(
        &self,
        plan_id: i64,
        attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let field_cultivation_id = Self::attr_i64(&attributes, "field_cultivation_id")
            .ok_or_else(|| Box::new(RecordNotFoundError) as Box<dyn std::error::Error + Send + Sync>)?;
        let task_type = Self::attr_str(&attributes, "task_type").unwrap_or_else(|| "field_work".into());
        let name = Self::attr_str(&attributes, "name")
            .ok_or_else(|| Box::new(RecordNotFoundError) as Box<dyn std::error::Error + Send + Sync>)?;
        let source = Self::attr_str(&attributes, "source").unwrap_or_else(|| "manual_entry".into());
        let scheduled_date = Self::attr_str(&attributes, "scheduled_date");
        let description = Self::attr_str(&attributes, "description");
        let stage_name = Self::attr_str(&attributes, "stage_name");
        let stage_order = Self::attr_i32(&attributes, "stage_order");
        let priority = Self::attr_i32(&attributes, "priority");
        let weather_dependency = Self::attr_str(&attributes, "weather_dependency");
        let time_per_sqm = Self::attr_decimal(&attributes, "time_per_sqm");
        let amount = Self::attr_decimal(&attributes, "amount");
        let amount_unit = Self::attr_str(&attributes, "amount_unit");
        let agricultural_task_id = Self::attr_i64(&attributes, "agricultural_task_id");

        self.pool.with_write_box(|conn| {
            let schedule_id =
                Self::find_or_create_schedule_id(conn, plan_id, field_cultivation_id)?;
            conn.execute(
                "INSERT INTO task_schedule_items (
                   task_schedule_id, task_type, name, description, stage_name, stage_order,
                   scheduled_date, priority, source, weather_dependency, time_per_sqm,
                   amount, amount_unit, agricultural_task_id, status, created_at, updated_at
                 ) VALUES (
                   ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                   datetime('now'), datetime('now')
                 )",
                params![
                    schedule_id,
                    task_type,
                    name,
                    description,
                    stage_name,
                    stage_order,
                    scheduled_date,
                    priority,
                    source,
                    weather_dependency,
                    time_per_sqm.map(|d| d.to_string()),
                    amount.map(|d| d.to_string()),
                    amount_unit,
                    agricultural_task_id,
                    PLANNED,
                ],
            )?;
            let item_id = conn.last_insert_rowid();
            Ok(Self::item_json_from_row(
                item_id,
                name,
                task_type,
                scheduled_date,
                PLANNED.to_string(),
                source,
                agricultural_task_id,
                None,
                None,
            ))
        })
    }

    fn update_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
        attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| -> Result<Value, rusqlite::Error> {
            if !Self::item_belongs_to_plan(conn, plan_id, item_id)? {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }

            let scheduled_date = Self::attr_str(&attributes, "scheduled_date");
            let status = Self::attr_str(&attributes, "status");
            let rescheduled_at = Self::attr_str(&attributes, "rescheduled_at");
            let amount = Self::attr_decimal(&attributes, "amount");
            let amount_unit = Self::attr_str(&attributes, "amount_unit");

            conn.execute(
                "UPDATE task_schedule_items SET
                   scheduled_date = COALESCE(?1, scheduled_date),
                   status = COALESCE(?2, status),
                   rescheduled_at = COALESCE(?3, rescheduled_at),
                   amount = COALESCE(?4, amount),
                   amount_unit = COALESCE(?5, amount_unit),
                   updated_at = datetime('now')
                 WHERE id = ?6",
                params![
                    scheduled_date,
                    status,
                    rescheduled_at,
                    amount.map(|d| d.to_string()),
                    amount_unit,
                    item_id,
                ],
            )?;

            conn.query_row(
                "SELECT name, task_type, scheduled_date, status, source, agricultural_task_id, \
                 rescheduled_at, cancelled_at \
                 FROM task_schedule_items WHERE id = ?1",
                params![item_id],
                |row| {
                    Ok(Self::item_json_from_row(
                        item_id,
                        row.get(0)?,
                        row.get(1)?,
                        row.get(2)?,
                        row.get(3)?,
                        row.get(4)?,
                        row.get(5)?,
                        row.get(6)?,
                        row.get(7)?,
                    ))
                },
            )
        })
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
