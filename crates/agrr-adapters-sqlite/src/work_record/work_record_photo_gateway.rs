//! SQLite metadata for work record photos.

use crate::pool::SqlitePool;
use agrr_domain::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoRow, WorkRecordPhotoStatus,
};
use rusqlite::{params, OptionalExtension};
use time::{format_description::well_known::Iso8601, OffsetDateTime};

pub struct WorkRecordPhotoSqliteGateway {
    pool: SqlitePool,
}

impl WorkRecordPhotoSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn parse_datetime(s: &str) -> OffsetDateTime {
        OffsetDateTime::parse(s, &Iso8601::DEFAULT).unwrap_or_else(|_| OffsetDateTime::now_utc())
    }

    fn format_datetime(dt: OffsetDateTime) -> String {
        dt.format(&Iso8601::DEFAULT)
            .unwrap_or_else(|_| dt.to_string())
    }

    fn row_from_query(row: &rusqlite::Row<'_>) -> rusqlite::Result<WorkRecordPhotoRow> {
        let status_raw: String = row.get(7)?;
        let status = WorkRecordPhotoStatus::parse(&status_raw).ok_or_else(|| {
            rusqlite::Error::InvalidColumnType(7, "status".into(), rusqlite::types::Type::Text)
        })?;
        Ok(WorkRecordPhotoRow {
            id: row.get(0)?,
            work_record_id: row.get(1)?,
            cultivation_plan_id: row.get(2)?,
            storage_key: row.get(3)?,
            content_type: row.get(4)?,
            byte_size: row.get(5)?,
            position: row.get(6)?,
            status,
            created_at: Self::parse_datetime(&row.get::<_, String>(8)?),
            updated_at: Self::parse_datetime(&row.get::<_, String>(9)?),
        })
    }

    const SELECT_COLS: &'static str =
        "id, work_record_id, cultivation_plan_id, storage_key, content_type, byte_size, position, status, created_at, updated_at";
}

impl WorkRecordPhotoGateway for WorkRecordPhotoSqliteGateway {
    fn count_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i32 = conn.query_row(
                "SELECT COUNT(*) FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2",
                params![plan_id, work_record_id],
                |row| row.get(0),
            )?;
            Ok(count)
        })
    }

    fn count_ready_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i32 = conn.query_row(
                "SELECT COUNT(*) FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND status = 'ready'",
                params![plan_id, work_record_id],
                |row| row.get(0),
            )?;
            Ok(count)
        })
    }

    fn insert_pending(
        &self,
        plan_id: i64,
        work_record_id: i64,
        storage_key: &str,
        content_type: &str,
        now: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO work_record_photos (\
                 work_record_id, cultivation_plan_id, storage_key, content_type, status, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, 'pending', ?5, ?6)",
                params![
                    work_record_id,
                    plan_id,
                    storage_key,
                    content_type,
                    Self::format_datetime(now),
                    Self::format_datetime(now),
                ],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                &format!("SELECT {} FROM work_record_photos WHERE id = ?1", Self::SELECT_COLS),
                params![id],
                Self::row_from_query,
            )
        })
    }

    fn find_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                &format!(
                    "SELECT {} FROM work_record_photos \
                     WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                    Self::SELECT_COLS
                ),
                params![plan_id, work_record_id, photo_id],
                Self::row_from_query,
            )
        })
    }

    fn mark_ready(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        byte_size: i64,
        position: i32,
        now: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let updated = conn.execute(
                "UPDATE work_record_photos \
                 SET status = 'ready', byte_size = ?4, position = ?5, updated_at = ?6 \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3 AND status = 'pending'",
                params![
                    plan_id,
                    work_record_id,
                    photo_id,
                    byte_size,
                    position,
                    Self::format_datetime(now),
                ],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            conn.query_row(
                &format!(
                    "SELECT {} FROM work_record_photos \
                     WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                    Self::SELECT_COLS
                ),
                params![plan_id, work_record_id, photo_id],
                Self::row_from_query,
            )
        })
    }

    fn delete(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let row = conn
                .query_row(
                    &format!(
                        "SELECT {} FROM work_record_photos \
                         WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                        Self::SELECT_COLS
                    ),
                    params![plan_id, work_record_id, photo_id],
                    Self::row_from_query,
                )
                .optional()?;
            let Some(row) = row else {
                return Ok(None);
            };
            conn.execute(
                "DELETE FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                params![plan_id, work_record_id, photo_id],
            )?;
            Ok(Some(row))
        })
    }

    fn list_ready_for_plan(
        &self,
        plan_id: i64,
        work_record_ids: &[i64],
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        if work_record_ids.is_empty() {
            return Ok(Vec::new());
        }
        self.pool.with_read_box(|conn| {
            let placeholders = (0..work_record_ids.len())
                .map(|_| "?")
                .collect::<Vec<_>>()
                .join(", ");
            let sql = format!(
                "SELECT {} FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND status = 'ready' AND work_record_id IN ({placeholders}) \
                 ORDER BY work_record_id ASC, position ASC",
                Self::SELECT_COLS
            );
            let mut values: Vec<Box<dyn rusqlite::types::ToSql>> =
                vec![Box::new(plan_id)];
            for id in work_record_ids {
                values.push(Box::new(*id));
            }
            let params: Vec<&dyn rusqlite::types::ToSql> =
                values.iter().map(|v| v.as_ref()).collect();
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(params.as_slice(), Self::row_from_query)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn work_record_exists(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i32 = conn.query_row(
                "SELECT COUNT(*) FROM work_records WHERE cultivation_plan_id = ?1 AND id = ?2",
                params![plan_id, work_record_id],
                |row| row.get(0),
            )?;
            Ok(count > 0)
        })
    }
}
