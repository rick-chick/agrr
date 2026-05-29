//! Ruby: `Adapters::Pest::Gateways::CropPestActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::pest::entities::CropPestLinkEntity;
use agrr_domain::pest::gateways::CropPestGateway;
use rusqlite::params;

pub struct CropPestSqliteGateway {
    pool: SqlitePool,
}

impl CropPestSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropPestGateway for CropPestSqliteGateway {
    fn find_by_crop_id_and_pest_id(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<Option<CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT rowid, crop_id, pest_id FROM crop_pests WHERE crop_id = ?1 AND pest_id = ?2",
                )?;
                let mut rows = stmt.query(params![crop_id, pest_id])?;
                if let Some(row) = rows.next()? {
                    return Ok(Some(CropPestLinkEntity::new(
                        row.get(0)?,
                        row.get(1)?,
                        row.get(2)?,
                    )));
                }
                Ok(None)
            })
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }

    fn list_by_pest_id(
        &self,
        pest_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt =
                conn.prepare("SELECT crop_id FROM crop_pests WHERE pest_id = ?1 ORDER BY crop_id")?;
            let rows = stmt.query_map(params![pest_id], |row| row.get(0))?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn create(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO crop_pests (crop_id, pest_id, created_at, updated_at) VALUES (?1, ?2, datetime('now'), datetime('now'))",
                params![crop_id, pest_id],
            )?;
            let id: i64 = conn.query_row(
                "SELECT rowid FROM crop_pests WHERE crop_id = ?1 AND pest_id = ?2",
                params![crop_id, pest_id],
                |row| row.get(0),
            )?;
            Ok(CropPestLinkEntity::new(id, crop_id, pest_id))
        })
    }

    fn delete(&self, crop_id: i64, pest_id: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let n = self.pool.with_write_box(|conn| {
            conn.execute(
                "DELETE FROM crop_pests WHERE crop_id = ?1 AND pest_id = ?2",
                params![crop_id, pest_id],
            )
        })?;
        Ok(n > 0)
    }
}
