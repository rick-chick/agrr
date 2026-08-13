//! Ruby: `TaskScheduleItemMutationActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::constants::task_schedule_item_statuses::{PLANNED, SKIPPED};
use agrr_domain::cultivation_plan::dtos::{
    TaskScheduleAgriculturalTaskSnapshot, TaskScheduleFieldCultivationSnapshot,
    TaskScheduleItemAmountSnapshot, TaskScheduleItemDeletionUndoScheduleRow,
};
use agrr_domain::cultivation_plan::gateways::TaskScheduleItemMutationGateway;
use agrr_domain::cultivation_plan::helpers::parse_iso_date;
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::exceptions::RecordInvalidError;
use rusqlite::{params, OptionalExtension};
use rust_decimal::Decimal;
use serde_json::{json, Value};
use std::str::FromStr;
use time::{format_description::well_known::Iso8601, Date, OffsetDateTime};

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

    fn format_date(date: Date) -> String {
        date.format(&Iso8601::DATE)
            .unwrap_or_else(|_| date.to_string())
    }

    fn item_belongs_to_plan(
        conn: &rusqlite::Connection,
        plan_id: i64,
        item_id: i64,
    ) -> rusqlite::Result<bool> {
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
        attrs.get(key).and_then(|v| match v {
            AttrValue::Str(s) => Some(s.clone()),
            AttrValue::Int(i) => Some(i.to_string()),
            AttrValue::Bool(b) => Some(b.to_string()),
            AttrValue::Null => None,
        })
    }

    fn attr_i64(attrs: &AttrMap, key: &str) -> Option<i64> {
        attrs.get(key).and_then(|v| match v {
            AttrValue::Int(i) => Some(*i),
            AttrValue::Str(s) => s.parse().ok(),
            _ => None,
        })
    }

    fn attr_decimal(attrs: &AttrMap, key: &str) -> Option<Decimal> {
        Self::attr_str(attrs, key).and_then(|s| Decimal::from_str(&s).ok())
    }

    fn find_schedule_id(
        conn: &rusqlite::Connection,
        plan_id: i64,
        field_cultivation_id: i64,
    ) -> rusqlite::Result<Option<i64>> {
        conn.query_row(
            "SELECT id FROM task_schedules \
             WHERE cultivation_plan_id = ?1 AND field_cultivation_id = ?2 AND category = 'general' \
             LIMIT 1",
            params![plan_id, field_cultivation_id],
            |row| row.get(0),
        )
        .optional()
    }

    fn ensure_schedule_id(
        conn: &rusqlite::Connection,
        plan_id: i64,
        field_cultivation_id: i64,
    ) -> rusqlite::Result<i64> {
        if let Some(id) = Self::find_schedule_id(conn, plan_id, field_cultivation_id)? {
            return Ok(id);
        }
        conn.execute(
            "INSERT INTO task_schedules (
               cultivation_plan_id, field_cultivation_id, category, status, source,
               generated_at, created_at, updated_at
             ) VALUES (?1, ?2, 'general', 'active', 'manual', datetime('now'), datetime('now'), datetime('now'))",
            params![plan_id, field_cultivation_id],
        )?;
        Ok(conn.last_insert_rowid())
    }

    fn item_payload(
        conn: &rusqlite::Connection,
        item_id: i64,
    ) -> rusqlite::Result<Value> {
        conn.query_row(
            "SELECT tsi.id, tsi.name, tsi.scheduled_date, tsi.status, ts.field_cultivation_id, \
             tsi.rescheduled_at \
             FROM task_schedule_items tsi \
             INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
             WHERE tsi.id = ?1",
            params![item_id],
            |row| {
                let rescheduled_at = match row.get::<_, rusqlite::types::Value>(5)? {
                    rusqlite::types::Value::Null => None,
                    rusqlite::types::Value::Text(s) => Some(s),
                    rusqlite::types::Value::Integer(i) => Some(i.to_string()),
                    rusqlite::types::Value::Real(f) => Some(f.to_string()),
                    _ => None,
                };
                Ok(json!({
                    "id": row.get::<_, i64>(0)?,
                    "name": row.get::<_, String>(1)?,
                    "scheduled_date": row.get::<_, Option<String>>(2)?,
                    "status": row.get::<_, String>(3)?,
                    "field_cultivation_id": row.get::<_, i64>(4)?,
                    "rescheduled_at": rescheduled_at,
                }))
            },
        )
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
                 WHERE fc.cultivation_plan_id = ?1 AND fc.id = ?2 \
                 LIMIT 1",
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
            Ok(conn
                .query_row(
                    "SELECT id, name, description, task_type, weather_dependency, CAST(time_per_sqm AS TEXT) \
                     FROM agricultural_tasks WHERE id = ?1 LIMIT 1",
                    params![task_id],
                    |row| {
                        let time_raw: Option<String> = row.get(5)?;
                        Ok(TaskScheduleAgriculturalTaskSnapshot {
                            id: row.get(0)?,
                            name: row.get(1)?,
                            description: row.get(2)?,
                            task_type: row.get(3)?,
                            weather_dependency: row.get(4)?,
                            time_per_sqm: time_raw.and_then(|s| Decimal::from_str(&s).ok()),
                        })
                    },
                )
                .optional()?)
        })
    }

    fn find_item_amount_snapshot(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<TaskScheduleItemAmountSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT CAST(tsi.amount AS TEXT), tsi.amount_unit, tsi.scheduled_date \
                 FROM task_schedule_items tsi \
                 INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                 WHERE ts.cultivation_plan_id = ?1 AND tsi.id = ?2 \
                 LIMIT 1",
                params![plan_id, item_id],
                |row| {
                    let amount_raw: Option<String> = row.get(0)?;
                    let scheduled_raw: String = row.get(2)?;
                    let scheduled_date = parse_iso_date(&scheduled_raw).ok_or_else(|| {
                        rusqlite::Error::InvalidColumnType(
                            2,
                            "scheduled_date".into(),
                            rusqlite::types::Type::Text,
                        )
                    })?;
                    Ok(TaskScheduleItemAmountSnapshot {
                        amount: amount_raw.and_then(|s| Decimal::from_str(&s).ok()),
                        amount_unit: row.get(1)?,
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
            .ok_or_else(|| RecordInvalidError::new(None, None))?;
        let task_type = Self::attr_str(&attributes, "task_type")
            .unwrap_or_else(|| "field_work".to_string());
        let name = Self::attr_str(&attributes, "name")
            .ok_or_else(|| RecordInvalidError::new(None, None))?;
        let description = Self::attr_str(&attributes, "description");
        let scheduled_date = Self::attr_str(&attributes, "scheduled_date");
        let stage_name = Self::attr_str(&attributes, "stage_name");
        let stage_order = Self::attr_i64(&attributes, "stage_order").map(|v| v as i32);
        let priority = Self::attr_i64(&attributes, "priority").map(|v| v as i32);
        let source = Self::attr_str(&attributes, "source").unwrap_or_else(|| "manual_entry".into());
        let weather_dependency = Self::attr_str(&attributes, "weather_dependency");
        let time_per_sqm = Self::attr_decimal(&attributes, "time_per_sqm");
        let amount = Self::attr_decimal(&attributes, "amount");
        let amount_unit = Self::attr_str(&attributes, "amount_unit");
        let agricultural_task_id = Self::attr_i64(&attributes, "agricultural_task_id");

        self.pool.with_write_box(|conn| {
            let schedule_id = Self::ensure_schedule_id(conn, plan_id, field_cultivation_id)?;
            conn.execute(
                "INSERT INTO task_schedule_items (
                   task_schedule_id, task_type, name, description, stage_name, stage_order,
                   scheduled_date, priority, source, weather_dependency, time_per_sqm, amount,
                   amount_unit, agricultural_task_id, status, created_at, updated_at
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
            Self::item_payload(conn, item_id)
        })
    }

    fn update_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
        attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            if !Self::item_belongs_to_plan(conn, plan_id, item_id)? {
                return Err(rusqlite::Error::QueryReturnedNoRows.into());
            }

            let mut sets: Vec<&str> = Vec::new();
            let mut values: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();

            macro_rules! push_str {
                ($col:expr, $key:expr) => {
                    if let Some(v) = Self::attr_str(&attributes, $key) {
                        sets.push(concat!($col, " = ?"));
                        values.push(Box::new(v));
                    }
                };
            }

            push_str!("scheduled_date", "scheduled_date");
            push_str!("status", "status");
            push_str!("rescheduled_at", "rescheduled_at");
            push_str!("amount_unit", "amount_unit");
            if let Some(v) = Self::attr_decimal(&attributes, "amount") {
                sets.push("amount = ?");
                values.push(Box::new(v.to_string()));
            }

            if sets.is_empty() {
                return Self::item_payload(conn, item_id);
            }

            sets.push("updated_at = datetime('now')");
            let sql = format!(
                "UPDATE task_schedule_items SET {} WHERE id = ?",
                sets.join(", ")
            );
            values.push(Box::new(item_id));
            let param_refs: Vec<&dyn rusqlite::ToSql> =
                values.iter().map(|p| p.as_ref()).collect();
            let updated = conn.execute(&sql, param_refs.as_slice())?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows.into());
            }
            Self::item_payload(conn, item_id)
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
