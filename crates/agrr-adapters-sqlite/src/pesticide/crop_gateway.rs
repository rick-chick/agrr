//! Crop reads for `MastersCropPesticidesIndexInteractor`.

use crate::pool::SqlitePool;
use agrr_domain::pesticide::gateways::{CropGateway, CropRecord};
use rusqlite::params;

pub struct PesticideCropSqliteGateway {
    pool: SqlitePool,
}

impl PesticideCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropGateway for PesticideCropSqliteGateway {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, is_reference, user_id FROM crops WHERE id = ?1",
                params![crop_id],
                |row| {
                    let is_reference: i64 = row.get(1)?;
                    Ok(CropRecord {
                        id: row.get(0)?,
                        is_reference: is_reference != 0,
                        user_id: row.get(2)?,
                    })
                },
            )
        })
    }
}
