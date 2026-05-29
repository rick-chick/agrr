//! Crop task template links for agricultural task update sync.

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::entities::CropTaskTemplateLinkEntity;
use agrr_domain::agricultural_task::gateways::CropTaskTemplateGateway;
use agrr_domain::shared::attr::AttrMap;
use rusqlite::params;

pub struct CropTaskTemplateSqliteGateway {
    pool: SqlitePool,
}

impl CropTaskTemplateSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropTaskTemplateGateway for CropTaskTemplateSqliteGateway {
    fn list_by_agricultural_task_id(
        &self,
        agricultural_task_id: i64,
    ) -> Result<Vec<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT crop_id FROM crop_task_templates WHERE agricultural_task_id = ?1",
            )?;
            let rows = stmt.query_map(params![agricultural_task_id], |row| {
                Ok(CropTaskTemplateLinkEntity::new(row.get(0)?))
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<Option<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
        match self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT crop_id FROM crop_task_templates WHERE agricultural_task_id = ?1 AND crop_id = ?2",
                params![agricultural_task_id, crop_id],
                |row| Ok(CropTaskTemplateLinkEntity::new(row.get(0)?)),
            )
        }) {
            Ok(link) => Ok(Some(link)),
            Err(e) if e.downcast_ref::<agrr_domain::shared::exceptions::RecordNotFoundError>().is_some() => {
                Ok(None)
            }
            Err(e) => Err(e),
        }
    }

    fn create(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
        _attrs: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO crop_task_templates (crop_id, agricultural_task_id, name, created_at, updated_at) \
                 SELECT ?1, ?2, COALESCE((SELECT name FROM agricultural_tasks WHERE id = ?2), 'task'), datetime('now'), datetime('now')",
                params![crop_id, agricultural_task_id],
            )?;
            Ok(())
        })
    }

    fn delete(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "DELETE FROM crop_task_templates WHERE agricultural_task_id = ?1 AND crop_id = ?2",
                params![agricultural_task_id, crop_id],
            )?;
            Ok(())
        })
    }
}
