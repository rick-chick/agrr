//! Ruby: `TaskScheduleActiveRecordGateway` — replace / delete for agrr-generated schedules.

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::dtos::TaskScheduleReplaceItem;
use agrr_domain::agricultural_task::gateways::TaskScheduleGateway;
use rusqlite::{params, OptionalExtension};
use rust_decimal::Decimal;
use time::{format_description::well_known::Iso8601, OffsetDateTime};

pub struct TaskScheduleSqliteGateway {
    pool: SqlitePool,
}

impl TaskScheduleSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn format_datetime(dt: OffsetDateTime) -> String {
        dt.format(&Iso8601::DEFAULT)
            .unwrap_or_else(|_| dt.unix_timestamp().to_string())
    }

    fn decimal_to_f64(value: Decimal) -> f64 {
        value.to_string().parse().unwrap_or(0.0)
    }

    fn optional_decimal_to_f64(value: Option<Decimal>) -> Option<f64> {
        value.map(Self::decimal_to_f64)
    }

    fn find_schedule_id(
        conn: &rusqlite::Connection,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
    ) -> rusqlite::Result<Option<i64>> {
        conn.query_row(
            "SELECT id FROM task_schedules \
             WHERE cultivation_plan_id = ?1 AND field_cultivation_id = ?2 AND category = ?3 \
             LIMIT 1",
            params![cultivation_plan_id, field_cultivation_id, category],
            |row| row.get(0),
        )
        .optional()
    }
}

impl TaskScheduleGateway for TaskScheduleSqliteGateway {
    fn delete_all_for_field_category(
        &self,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let Some(schedule_id) =
                Self::find_schedule_id(conn, cultivation_plan_id, field_cultivation_id, category)?
            else {
                return Ok(());
            };
            conn.execute(
                "DELETE FROM task_schedule_items WHERE task_schedule_id = ?1",
                params![schedule_id],
            )?;
            conn.execute("DELETE FROM task_schedules WHERE id = ?1", params![schedule_id])?;
            Ok(())
        })
    }

    fn replace_schedule_for_field_category(
        &self,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
        generated_at: OffsetDateTime,
        items: Vec<TaskScheduleReplaceItem>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let generated_at_str = Self::format_datetime(generated_at);
        self.pool.with_write_box(|conn| {
            let schedule_id = match Self::find_schedule_id(
                conn,
                cultivation_plan_id,
                field_cultivation_id,
                category,
            )? {
                Some(id) => {
                    conn.execute(
                        "DELETE FROM task_schedule_items WHERE task_schedule_id = ?1",
                        params![id],
                    )?;
                    conn.execute(
                        "UPDATE task_schedules SET generated_at = ?1, updated_at = datetime('now') \
                         WHERE id = ?2",
                        params![generated_at_str, id],
                    )?;
                    id
                }
                None => {
                    conn.execute(
                        "INSERT INTO task_schedules (cultivation_plan_id, field_cultivation_id, category, \
                         status, source, generated_at, created_at, updated_at) \
                         VALUES (?1, ?2, ?3, 'active', 'agrr', ?4, datetime('now'), datetime('now'))",
                        params![
                            cultivation_plan_id,
                            field_cultivation_id,
                            category,
                            generated_at_str,
                        ],
                    )?;
                    conn.last_insert_rowid()
                }
            };

            for item in items {
                conn.execute(
                    "INSERT INTO task_schedule_items (task_schedule_id, task_type, name, description, \
                     stage_name, stage_order, gdd_trigger, gdd_tolerance, scheduled_date, priority, \
                     source, weather_dependency, time_per_sqm, amount, amount_unit, status, \
                     agricultural_task_id, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, \
                     datetime('now'), datetime('now'))",
                    params![
                        schedule_id,
                        item.task_type,
                        item.name,
                        item.description,
                        item.stage_name,
                        item.stage_order,
                        Self::decimal_to_f64(item.gdd_trigger),
                        Self::optional_decimal_to_f64(item.gdd_tolerance),
                        item.scheduled_date.to_string(),
                        item.priority,
                        item.source,
                        item.weather_dependency,
                        Self::optional_decimal_to_f64(item.time_per_sqm),
                        Self::optional_decimal_to_f64(item.amount),
                        item.amount_unit,
                        item.status,
                        item.agricultural_task_id,
                    ],
                )?;
            }
            Ok(())
        })
    }
}
