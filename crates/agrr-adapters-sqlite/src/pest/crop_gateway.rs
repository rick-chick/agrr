//! Crop reads for pest association (`Domain::Pest::Gateways::CropGateway`).

use crate::pool::SqlitePool;
use agrr_domain::pest::gateways::{CropGateway, CropRecord};
use rusqlite::params;

pub struct PestCropSqliteGateway {
    pool: SqlitePool,
}

impl PestCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropGateway for PestCropSqliteGateway {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read_box(|conn| {
                conn.query_row(
                    "SELECT id, is_reference, user_id, region, name FROM crops WHERE id = ?1",
                    params![crop_id],
                    |row| {
                        let is_reference: i64 = row.get(1)?;
                        Ok(CropRecord {
                            id: row.get(0)?,
                            is_reference: is_reference != 0,
                            user_id: row.get(2)?,
                            region: row.get(3)?,
                            name: row.get(4)?,
                        })
                    },
                )
            })
            .map(Some)
            .or_else(|err| {
                if err.downcast_ref::<agrr_domain::shared::exceptions::RecordNotFoundError>().is_some() {
                    Ok(None)
                } else {
                    Err(err)
                }
            })
    }

    fn list_by_name(
        &self,
        _name: &str,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Vec::new())
    }
}
