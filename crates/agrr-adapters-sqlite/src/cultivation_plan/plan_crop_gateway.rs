//! Ruby: `CultivationPlanPlanCropActiveRecordGateway` — P6 public plan create slice.

use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::AddCropCropSnapshot;
use agrr_domain::cultivation_plan::dtos::{
    CultivationPlanCropSnapshot, CultivationPlanPlanCropCreateAttrs,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanPlanCropGateway;
use rusqlite::params;

pub struct CultivationPlanPlanCropSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanPlanCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CultivationPlanPlanCropGateway for CultivationPlanPlanCropSqliteGateway {
    fn create_for_plan(
        &self,
        attrs: &CultivationPlanPlanCropCreateAttrs,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO cultivation_plan_crops \
                 (cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))",
                params![
                    attrs.plan_id,
                    attrs.crop_id,
                    attrs.name,
                    attrs.variety,
                    attrs.area_per_unit,
                    attrs.revenue_per_area,
                ],
            )?;
            Ok(())
        })
    }

    fn create(
        &self,
        plan_id: i64,
        crop_entity: &AddCropCropSnapshot,
    ) -> Result<CultivationPlanCropSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let exists: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plans WHERE id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            if exists == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            conn.execute(
                "INSERT INTO cultivation_plan_crops \
                 (cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))",
                params![
                    plan_id,
                    crop_entity.id,
                    crop_entity.name,
                    crop_entity.variety,
                    crop_entity.area_per_unit,
                    crop_entity.revenue_per_area,
                ],
            )?;
            let plan_crop_id = conn.last_insert_rowid();
            let display_name = match &crop_entity.variety {
                Some(v) if !v.is_empty() => format!("{} ({})", crop_entity.name, v),
                _ => crop_entity.name.clone(),
            };
            Ok(CultivationPlanCropSnapshot {
                id: plan_crop_id,
                display_name,
            })
        })
    }

    fn delete(&self, id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let changed = conn.execute(
                "DELETE FROM cultivation_plan_crops WHERE id = ?1",
                params![id],
            )?;
            if changed == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(())
        })
    }
}
