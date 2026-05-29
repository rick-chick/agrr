//! Ruby: `FieldCultivationSyncPlanReadActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::field_cultivation::dtos::{
    FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
};
use agrr_domain::field_cultivation::gateways::FieldCultivationSyncPlanReadGateway;
use rusqlite::params;

pub struct FieldCultivationSyncPlanReadSqliteGateway {
    pool: SqlitePool,
}

impl FieldCultivationSyncPlanReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn ensure_plan_exists(conn: &rusqlite::Connection, plan_id: i64) -> rusqlite::Result<()> {
    conn.query_row(
        "SELECT 1 FROM cultivation_plans WHERE id = ?1",
        params![plan_id],
        |_| Ok(()),
    )
}

impl FieldCultivationSyncPlanReadGateway for FieldCultivationSyncPlanReadSqliteGateway {
    fn list_sync_plan_field_ids_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            ensure_plan_exists(conn, plan_id)?;
            let mut stmt = conn.prepare(
                "SELECT id FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| row.get(0))?;
            rows.collect::<Result<Vec<_>, _>>()
        })
    }

    fn list_sync_plan_crop_entries_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<FieldCultivationSyncPlanCropEntry>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            ensure_plan_exists(conn, plan_id)?;
            let mut stmt = conn.prepare(
                "SELECT cpc.id, cpc.crop_id \
                 FROM cultivation_plan_crops cpc \
                 WHERE cpc.cultivation_plan_id = ?1 \
                 ORDER BY cpc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let plan_crop_id: i64 = row.get(0)?;
                let crop_id: Option<i64> = row.get(1)?;
                Ok(FieldCultivationSyncPlanCropEntry {
                    plan_crop_id,
                    crop_id: crop_id
                        .map(|id| id.to_string())
                        .unwrap_or_default(),
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>()
        })
    }

    fn list_sync_existing_field_cultivation_entries_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<
        Vec<FieldCultivationSyncExistingFieldCultivationEntry>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        self.pool.with_read_box(|conn| {
            ensure_plan_exists(conn, plan_id)?;
            let mut stmt = conn.prepare(
                "SELECT fc.id, fc.cultivation_plan_crop_id, cpc.crop_id \
                 FROM field_cultivations fc \
                 INNER JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
                 WHERE fc.cultivation_plan_id = ?1 \
                 ORDER BY fc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let field_cultivation_id: i64 = row.get(0)?;
                let cultivation_plan_crop_id: i64 = row.get(1)?;
                let crop_id: Option<i64> = row.get(2)?;
                Ok(FieldCultivationSyncExistingFieldCultivationEntry {
                    field_cultivation_id,
                    cultivation_plan_crop_id,
                    crop_id: crop_id
                        .map(|id| id.to_string())
                        .unwrap_or_default(),
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>()
        })
    }
}
