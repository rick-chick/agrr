//! Crop stage read port for masters nested routes.

use crate::pool::SqlitePool;
use agrr_domain::crop::entities::CropStageEntity;
use agrr_domain::crop::gateways::CropStageGateway;
use rusqlite::params;

pub struct CropStageSqliteGateway {
    pool: SqlitePool,
}

impl CropStageSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropStageGateway for CropStageSqliteGateway {
    fn find_by_id(
        &self,
        crop_stage_id: i64,
    ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, crop_id, name, \"order\", created_at, updated_at FROM crop_stages WHERE id = ?1",
                params![crop_stage_id],
                |row| {
                    Ok(CropStageEntity {
                        id: row.get(0)?,
                        crop_id: row.get(1)?,
                        name: row.get(2)?,
                        order: row.get(3)?,
                        temperature_requirement: None,
                        thermal_requirement: None,
                        sunshine_requirement: None,
                        nutrient_requirement: None,
                        created_at: row.get(4)?,
                        updated_at: row.get(5)?,
                    })
                },
            )
        })
    }
}
