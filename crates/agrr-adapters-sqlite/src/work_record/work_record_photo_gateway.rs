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
        self.insert_pending_under_limit(
            plan_id,
            work_record_id,
            storage_key,
            content_type,
            i32::MAX,
            now,
        )?
        .ok_or_else(|| rusqlite::Error::QueryReturnedNoRows.into())
    }

    fn insert_pending_under_limit(
        &self,
        plan_id: i64,
        work_record_id: i64,
        storage_key: &str,
        content_type: &str,
        max_photos: i32,
        now: OffsetDateTime,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_transaction_box(|conn| {
            let count: i32 = conn.query_row(
                "SELECT COUNT(*) FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2",
                params![plan_id, work_record_id],
                |row| row.get(0),
            )?;
            if count >= max_photos {
                return Ok(None);
            }
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
            let row = conn.query_row(
                &format!("SELECT {} FROM work_record_photos WHERE id = ?1", Self::SELECT_COLS),
                params![id],
                Self::row_from_query,
            )?;
            Ok(Some(row))
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

    fn mark_ready_under_limit(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        byte_size: i64,
        max_ready: i32,
        now: OffsetDateTime,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_transaction_box(|conn| {
            let status: Option<String> = conn
                .query_row(
                    "SELECT status FROM work_record_photos \
                     WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                    params![plan_id, work_record_id, photo_id],
                    |row| row.get(0),
                )
                .optional()?;
            let Some(status) = status else {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            };
            if status != "pending" {
                return Ok(None);
            }

            let ready_count: i32 = conn.query_row(
                "SELECT COUNT(*) FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND status = 'ready'",
                params![plan_id, work_record_id],
                |row| row.get(0),
            )?;
            if ready_count >= max_ready {
                return Ok(None);
            }

            let updated = conn.execute(
                "UPDATE work_record_photos \
                 SET status = 'ready', byte_size = ?4, position = ?5, updated_at = ?6 \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3 AND status = 'pending'",
                params![
                    plan_id,
                    work_record_id,
                    photo_id,
                    byte_size,
                    ready_count,
                    Self::format_datetime(now),
                ],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            let row = conn.query_row(
                &format!(
                    "SELECT {} FROM work_record_photos \
                     WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3",
                    Self::SELECT_COLS
                ),
                params![plan_id, work_record_id, photo_id],
                Self::row_from_query,
            )?;
            Ok(Some(row))
        })
    }

    fn touch_pending_updated_at(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        now: OffsetDateTime,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let updated = conn.execute(
                "UPDATE work_record_photos SET updated_at = ?4 \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 AND id = ?3 AND status = 'pending'",
                params![
                    plan_id,
                    work_record_id,
                    photo_id,
                    Self::format_datetime(now),
                ],
            )?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(())
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

    fn delete_stale_pending_older_than(
        &self,
        plan_id: i64,
        work_record_id: i64,
        cutoff: OffsetDateTime,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let cutoff_str = Self::format_datetime(cutoff);
            let mut stmt = conn.prepare(&format!(
                "SELECT {} FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 \
                   AND status = 'pending' AND updated_at < ?3",
                Self::SELECT_COLS
            ))?;
            let rows = stmt
                .query_map(params![plan_id, work_record_id, cutoff_str], Self::row_from_query)?
                .collect::<Result<Vec<_>, _>>()?;
            if rows.is_empty() {
                return Ok(Vec::new());
            }
            conn.execute(
                "DELETE FROM work_record_photos \
                 WHERE cultivation_plan_id = ?1 AND work_record_id = ?2 \
                   AND status = 'pending' AND updated_at < ?3",
                params![plan_id, work_record_id, cutoff_str],
            )?;
            Ok(rows)
        })
    }
}
