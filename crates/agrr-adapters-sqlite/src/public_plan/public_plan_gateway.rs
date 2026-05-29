//! Ruby: `PublicPlanActiveRecordGateway`

use crate::crop::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::public_plan::catalog::{FarmSizeCatalog, FarmSizeRecord};
use agrr_domain::public_plan::dtos::{PublicPlanCrop, PublicPlanFarm};
use agrr_domain::public_plan::gateways::PublicPlanGateway;
use rusqlite::params;

pub struct PublicPlanSqliteGateway {
    pool: SqlitePool,
}

impl PublicPlanSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl PublicPlanGateway for PublicPlanSqliteGateway {
    fn find_by_farm_id(&self, farm_id: i64) -> Option<PublicPlanFarm> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT id, name, region FROM farms WHERE id = ?1 LIMIT 1",
                )?;
                let row = stmt.query_row(params![farm_id], |row| {
                    Ok(PublicPlanFarm {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        region: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                    })
                });
                match row {
                    Ok(farm) => Ok(Some(farm)),
                    Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                    Err(e) => Err(e),
                }
            })
            .ok()
            .flatten()
    }

    fn find_by_farm_size_id(&self, farm_size_id: &str) -> Option<FarmSizeRecord> {
        FarmSizeCatalog::find_by_id(farm_size_id).map(Into::into)
    }

    fn list_by_ids(&self, crop_ids: &[i64], region: &str) -> Vec<PublicPlanCrop> {
        let ids: Vec<i64> = crop_ids
            .iter()
            .copied()
            .filter(|id| *id != 0)
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .collect();
        if ids.is_empty() {
            return vec![];
        }
        let crop_gw = CropSqliteGateway::new(self.pool.clone());
        let mut crops = match crop_gw.list_by_is_reference(true, Some(region)) {
            Ok(all) => all,
            Err(_) => return vec![],
        };
        crops.retain(|c| ids.contains(&c.id));
        ids.iter()
            .filter_map(|id| crops.iter().find(|c| c.id == *id))
            .map(|c| PublicPlanCrop {
                id: c.id,
                name: c.name.clone(),
            })
            .collect()
    }
}
