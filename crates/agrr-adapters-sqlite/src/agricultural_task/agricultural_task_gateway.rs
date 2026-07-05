//! Ruby: `Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::attr_sql::{attr_bool, attr_f64, attr_i64, attr_str, require_str};
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::agricultural_task::dtos::{AgriculturalTaskShowDetail, AssociatedCrop};
use agrr_domain::agricultural_task::dtos::UndoEntity;
use agrr_domain::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
use agrr_domain::agricultural_task::gateways::{AgriculturalTaskGateway, SoftDeleteUndoResult};
use agrr_domain::shared::attr::AttrMap;
use agrr_domain::shared::user::User;
use rusqlite::{params, types::Value};

pub struct AgriculturalTaskSqliteGateway {
    pool: SqlitePool,
}

impl AgriculturalTaskSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    const SELECT_COLS: &'static str =
        "id, user_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, region, task_type, is_reference, created_at, updated_at";

    fn row_to_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<AgriculturalTaskEntity> {
        let is_reference: i64 = row.get(10)?;
        let tools_raw: Option<String> = row.get(6)?;
        let required_tools = tools_raw
            .and_then(|s| serde_json::from_str::<Vec<String>>(&s).ok())
            .unwrap_or_default();
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(row.get(0)?),
            user_id: row.get(1)?,
            name: row.get(2)?,
            description: row.get(3)?,
            time_per_sqm: row.get(4)?,
            weather_dependency: row.get(5)?,
            required_tools,
            skill_level: row.get(7)?,
            region: row.get(8)?,
            task_type: row.get(9)?,
            is_reference: is_reference != 0,
            created_at: row.get(11)?,
            updated_at: row.get(12)?,
        })
        .map_err(|e| {
            rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }

    fn list_sql(
        &self,
        base_sql: &str,
        bind: &[&dyn rusqlite::types::ToSql],
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(base_sql)?;
            let rows = stmt.query_map(rusqlite::params_from_iter(bind.iter()), Self::row_to_entity)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }
}

impl AgriculturalTaskGateway for AgriculturalTaskSqliteGateway {
    fn list_user_owned_tasks(
        &self,
        user_id: i64,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if let Some(q) = query.filter(|s| !s.trim().is_empty()) {
            let pattern = format!("%{}%", q.trim());
            let sql = format!(
                "SELECT {} FROM agricultural_tasks WHERE is_reference = 0 AND user_id = ?1 AND name LIKE ?2 ORDER BY name",
                Self::SELECT_COLS
            );
            return self.list_sql(&sql, &[&user_id, &pattern]);
        }
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE is_reference = 0 AND user_id = ?1 ORDER BY name",
            Self::SELECT_COLS
        );
        self.list_sql(&sql, &[&user_id])
    }

    fn list_reference_tasks(
        &self,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if let Some(q) = query.filter(|s| !s.trim().is_empty()) {
            let pattern = format!("%{}%", q.trim());
            let sql = format!(
                "SELECT {} FROM agricultural_tasks WHERE is_reference = 1 AND name LIKE ?1 ORDER BY name",
                Self::SELECT_COLS
            );
            return self.list_sql(&sql, &[&pattern]);
        }
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE is_reference = 1 ORDER BY name",
            Self::SELECT_COLS
        );
        self.list_sql(&sql, &[])
    }

    fn list_user_and_reference_tasks(
        &self,
        user_id: i64,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if let Some(q) = query.filter(|s| !s.trim().is_empty()) {
            let pattern = format!("%{}%", q.trim());
            let sql = format!(
                "SELECT {} FROM agricultural_tasks WHERE (is_reference = 1 OR user_id = ?1) AND name LIKE ?2 ORDER BY name",
                Self::SELECT_COLS
            );
            return self.list_sql(&sql, &[&user_id, &pattern]);
        }
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE is_reference = 1 OR user_id = ?1 ORDER BY name",
            Self::SELECT_COLS
        );
        self.list_sql(&sql, &[&user_id])
    }

    fn find_agricultural_task_show_detail(
        &self,
        id: i64,
    ) -> Result<AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        let task = self.find_by_id(id)?;
        let associated_crops = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT DISTINCT c.id, c.name FROM crops c \
                 INNER JOIN crop_task_schedule_blueprints b ON b.crop_id = c.id \
                 WHERE b.agricultural_task_id = ?1 ORDER BY c.name",
            )?;
            let rows = stmt.query_map(params![id], |row| {
                Ok(AssociatedCrop {
                    id: row.get(0)?,
                    name: row.get(1)?,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok::<_, rusqlite::Error>(out)
        })?;
        Ok(AgriculturalTaskShowDetail {
            task,
            associated_crops,
        })
    }

    fn find_by_id(
        &self,
        id: i64,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE id = ?1",
            Self::SELECT_COLS
        );
        self.pool
            .with_read_box(|conn| conn.query_row(&sql, params![id], Self::row_to_entity))
    }

    fn find_by_reference_and_name(
        &self,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE is_reference = 1 AND name = ?1 LIMIT 1",
            Self::SELECT_COLS
        );
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let mut rows = stmt.query_map(params![name], Self::row_to_entity)?;
            match rows.next() {
                Some(Ok(e)) => Ok(Some(e)),
                Some(Err(e)) => Err(e),
                None => Ok(None),
            }
        })
    }

    fn find_by_user_id_and_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!(
            "SELECT {} FROM agricultural_tasks WHERE is_reference = 0 AND user_id = ?1 AND name = ?2 LIMIT 1",
            Self::SELECT_COLS
        );
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let mut rows = stmt.query_map(params![user_id, name], Self::row_to_entity)?;
            match rows.next() {
                Some(Ok(e)) => Ok(Some(e)),
                Some(Err(e)) => Err(e),
                None => Ok(None),
            }
        })
    }

    fn create(
        &self,
        attrs: AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = require_str(&attrs, "name")?;
        let is_reference = attr_bool(&attrs, "is_reference").unwrap_or(false);
        let user_id = if is_reference {
            None
        } else {
            attr_i64(&attrs, "user_id")
        };
        let tools_json = "[]";
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO agricultural_tasks (name, description, time_per_sqm, weather_dependency, required_tools, skill_level, is_reference, user_id, region, task_type, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, datetime('now'), datetime('now'))",
                params![
                    name,
                    attr_str(&attrs, "description"),
                    attr_f64(&attrs, "time_per_sqm"),
                    attr_str(&attrs, "weather_dependency"),
                    tools_json,
                    attr_str(&attrs, "skill_level"),
                    if is_reference { 1 } else { 0 },
                    user_id,
                    attr_str(&attrs, "region"),
                    attr_str(&attrs, "task_type"),
                ],
            )?;
            let id = conn.last_insert_rowid();
            let sql = format!("SELECT {} FROM agricultural_tasks WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn update(
        &self,
        id: i64,
        attrs: AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets = Vec::new();
        let mut values: Vec<Value> = Vec::new();
        for key in [
            "name",
            "description",
            "weather_dependency",
            "skill_level",
            "region",
            "task_type",
        ] {
            if let Some(s) = attr_str(&attrs, key) {
                sets.push(format!("{key} = ?"));
                values.push(Value::Text(s));
            }
        }
        if let Some(v) = attr_f64(&attrs, "time_per_sqm") {
            sets.push("time_per_sqm = ?".into());
            values.push(Value::Real(v));
        }
        if let Some(b) = attr_bool(&attrs, "is_reference") {
            sets.push("is_reference = ?".into());
            values.push(Value::Integer(if b { 1 } else { 0 }));
        }
        if sets.is_empty() {
            return self.find_by_id(id);
        }
        sets.push("updated_at = datetime('now')".into());
        let sql = format!("UPDATE agricultural_tasks SET {} WHERE id = ?", sets.join(", "));
        values.push(Value::Integer(id));
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            let sql = format!("SELECT {} FROM agricultural_tasks WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T,
    {
        block()
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        task_id: i64,
        auto_hide_after: i64,
        toast_message: &str,
    ) -> Result<SoftDeleteUndoResult, Box<dyn std::error::Error + Send + Sync>> {
        let task = self.find_by_id(task_id)?;
        match schedule_soft_delete_json(
            self.pool.clone(),
            "AgriculturalTask",
            task_id,
            user.id,
            toast_message,
            auto_hide_after,
            Some(&task.name),
        ) {
            SoftDeleteJsonOutcome::Success(undo) => Ok(SoftDeleteUndoResult::Success {
                undo: UndoEntity { raw: undo },
            }),
            SoftDeleteJsonOutcome::Failure(error) => Ok(SoftDeleteUndoResult::Failure { error }),
        }
    }
}
