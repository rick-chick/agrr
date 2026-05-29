//! Minimal crop reads for agricultural task template sync.

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::gateways::{CropGateway, CropRecord};
use rusqlite::params;

pub struct AgTaskCropSqliteGateway {
    pool: SqlitePool,
}

impl AgTaskCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn map_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CropRecord> {
        let is_reference: i64 = row.get(1)?;
        Ok(CropRecord {
            id: row.get(0)?,
            is_reference: is_reference != 0,
            user_id: row.get(2)?,
        })
    }
}

impl CropGateway for AgTaskCropSqliteGateway {
    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
        let sql = if region.is_some() {
            "SELECT id, is_reference, user_id FROM crops WHERE is_reference = ?1 AND region = ?2"
        } else {
            "SELECT id, is_reference, user_id FROM crops WHERE is_reference = ?1"
        };
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(sql)?;
            let rows = if let Some(r) = region {
                stmt.query_map(params![if is_reference { 1 } else { 0 }, r], Self::map_row)?
            } else {
                stmt.query_map(params![if is_reference { 1 } else { 0 }], Self::map_row)?
            };
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn list_by_user_id(
        &self,
        user_id: i64,
        region: Option<&str>,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
        let sql = if region.is_some() {
            "SELECT id, is_reference, user_id FROM crops WHERE user_id = ?1 AND region = ?2"
        } else {
            "SELECT id, is_reference, user_id FROM crops WHERE user_id = ?1"
        };
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(sql)?;
            let rows = if let Some(r) = region {
                stmt.query_map(params![user_id, r], Self::map_row)?
            } else {
                stmt.query_map(params![user_id], Self::map_row)?
            };
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, is_reference, user_id FROM crops WHERE id = ?1",
                params![crop_id],
                Self::map_row,
            )
        })
    }
}
