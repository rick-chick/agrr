//! Ruby: `TaskScheduleActiveRecordGateway` — replace / delete for agrr-generated schedules.

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::dtos::{
    TaskScheduleFieldMutation, TaskSchedulePlanMutations, TaskScheduleReplaceItem,
};
use agrr_domain::agricultural_task::gateways::TaskScheduleGateway;
use rusqlite::{params, Connection, OptionalExtension};
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
        conn: &Connection,
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

    fn delete_all_for_field_category_on_conn(
        conn: &Connection,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
    ) -> rusqlite::Result<()> {
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
    }

    fn replace_schedule_for_field_category_on_conn(
        conn: &Connection,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
        generated_at_str: &str,
        items: &[TaskScheduleReplaceItem],
    ) -> rusqlite::Result<()> {
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
            Self::delete_all_for_field_category_on_conn(
                conn,
                cultivation_plan_id,
                field_cultivation_id,
                category,
            )
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
            Self::replace_schedule_for_field_category_on_conn(
                conn,
                cultivation_plan_id,
                field_cultivation_id,
                category,
                &generated_at_str,
                &items,
            )
        })
    }

    fn apply_plan_schedule_mutations(
        &self,
        plan_mutations: &TaskSchedulePlanMutations,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if plan_mutations.mutations.is_empty() {
            return Ok(());
        }
        let generated_at_str = Self::format_datetime(plan_mutations.generated_at);
        let cultivation_plan_id = plan_mutations.cultivation_plan_id;
        self.pool.with_write_transaction_box(|conn| {
            for mutation in &plan_mutations.mutations {
                match mutation {
                    TaskScheduleFieldMutation::DeleteAll {
                        field_cultivation_id,
                        category,
                    } => Self::delete_all_for_field_category_on_conn(
                        conn,
                        cultivation_plan_id,
                        *field_cultivation_id,
                        category,
                    )?,
                    TaskScheduleFieldMutation::Replace {
                        field_cultivation_id,
                        category,
                        items,
                    } => Self::replace_schedule_for_field_category_on_conn(
                        conn,
                        cultivation_plan_id,
                        *field_cultivation_id,
                        category,
                        &generated_at_str,
                        items,
                    )?,
                }
            }
            Ok(())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::agricultural_task::constants::schedule_item_types::FIELD_WORK;
    use agrr_domain::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
    use rust_decimal::Decimal;
    use std::str::FromStr;
    use time::{Date, Month};

    const GATEWAY_DDL: &str = "
CREATE TABLE field_cultivations (id INTEGER PRIMARY KEY);
INSERT INTO field_cultivations (id) VALUES (100), (200);
CREATE TABLE task_schedules (
  id INTEGER PRIMARY KEY,
  cultivation_plan_id INTEGER NOT NULL,
  field_cultivation_id INTEGER NOT NULL REFERENCES field_cultivations(id),
  category TEXT NOT NULL,
  status TEXT NOT NULL,
  source TEXT NOT NULL,
  generated_at TEXT,
  created_at TEXT,
  updated_at TEXT
);
CREATE TABLE task_schedule_items (
  id INTEGER PRIMARY KEY,
  task_schedule_id INTEGER NOT NULL,
  task_type TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  stage_name TEXT,
  stage_order INTEGER,
  gdd_trigger REAL NOT NULL,
  gdd_tolerance REAL,
  scheduled_date TEXT NOT NULL,
  priority INTEGER,
  source TEXT,
  weather_dependency TEXT,
  time_per_sqm REAL,
  amount REAL,
  amount_unit TEXT,
  status TEXT NOT NULL,
  agricultural_task_id INTEGER,
  created_at TEXT,
  updated_at TEXT
);
";

    fn test_pool(tag: &str) -> SqlitePool {
        let dir = std::env::temp_dir().join(format!(
            "agrr_task_schedule_gateway_{}_{tag}_{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("clock")
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test.sqlite3");
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch("PRAGMA foreign_keys = ON;")?;
            conn.execute_batch(GATEWAY_DDL)?;
            conn.execute(
                "INSERT INTO task_schedules \
                 (id, cultivation_plan_id, field_cultivation_id, category, status, source, generated_at) \
                 VALUES (1, 10, 100, 'general', 'active', 'agrr', '2026-01-01T00:00:00Z')",
                [],
            )?;
            conn.execute(
                "INSERT INTO task_schedule_items \
                 (id, task_schedule_id, task_type, name, scheduled_date, gdd_trigger, status) \
                 VALUES (1, 1, 'field_work', 'old item', '2026-01-01', 0.0, 'planned')",
                [],
            )?;
            conn.execute(
                "INSERT INTO task_schedules \
                 (id, cultivation_plan_id, field_cultivation_id, category, status, source, generated_at) \
                 VALUES (2, 10, 200, 'general', 'active', 'agrr', '2026-01-01T00:00:00Z')",
                [],
            )?;
            conn.execute(
                "INSERT INTO task_schedule_items \
                 (id, task_schedule_id, task_type, name, scheduled_date, gdd_trigger, status) \
                 VALUES (2, 2, 'field_work', 'field2 old', '2026-01-01', 0.0, 'planned')",
                [],
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    fn sample_item(name: &str) -> TaskScheduleReplaceItem {
        TaskScheduleReplaceItem {
            task_type: FIELD_WORK.to_string(),
            agricultural_task_id: None,
            name: name.to_string(),
            description: None,
            stage_name: None,
            stage_order: None,
            gdd_trigger: Decimal::from_str("10").unwrap(),
            gdd_tolerance: None,
            scheduled_date: Date::from_calendar_date(2026, Month::January, 15).unwrap(),
            priority: None,
            source: Some("agrr".to_string()),
            status: PLANNED.to_string(),
            weather_dependency: None,
            time_per_sqm: None,
            amount: None,
            amount_unit: None,
        }
    }

    fn item_name(pool: &SqlitePool, schedule_id: i64) -> String {
        pool.with_read(|conn| {
            conn.query_row(
                "SELECT name FROM task_schedule_items WHERE task_schedule_id = ?1 LIMIT 1",
                params![schedule_id],
                |row| row.get(0),
            )
        })
        .unwrap()
    }

    #[test]
    fn apply_plan_schedule_mutations_rolls_back_on_failure() {
        let pool = test_pool("rollback");
        let gateway = TaskScheduleSqliteGateway::new(pool.clone());
        let generated_at = OffsetDateTime::now_utc();

        let result = gateway.apply_plan_schedule_mutations(&TaskSchedulePlanMutations {
            cultivation_plan_id: 10,
            generated_at,
            mutations: vec![
                TaskScheduleFieldMutation::Replace {
                    field_cultivation_id: 100,
                    category: "general".to_string(),
                    items: vec![sample_item("new field1")],
                },
                TaskScheduleFieldMutation::Replace {
                    field_cultivation_id: 999,
                    category: "general".to_string(),
                    items: vec![sample_item("orphan field")],
                },
            ],
        });

        assert!(result.is_err(), "unknown field_cultivation_id should fail the batch");
        assert_eq!(item_name(&pool, 1), "old item");
        assert_eq!(item_name(&pool, 2), "field2 old");
    }

    #[test]
    fn apply_plan_schedule_mutations_commits_all_fields_together() {
        let pool = test_pool("commit");
        let gateway = TaskScheduleSqliteGateway::new(pool.clone());
        let generated_at = OffsetDateTime::now_utc();

        gateway
            .apply_plan_schedule_mutations(&TaskSchedulePlanMutations {
                cultivation_plan_id: 10,
                generated_at,
                mutations: vec![
                    TaskScheduleFieldMutation::Replace {
                        field_cultivation_id: 100,
                        category: "general".to_string(),
                        items: vec![sample_item("new field1")],
                    },
                    TaskScheduleFieldMutation::Replace {
                        field_cultivation_id: 200,
                        category: "general".to_string(),
                        items: vec![sample_item("new field2")],
                    },
                ],
            })
            .expect("batch apply");

        assert_eq!(item_name(&pool, 1), "new field1");
        assert_eq!(item_name(&pool, 2), "new field2");
    }
}
