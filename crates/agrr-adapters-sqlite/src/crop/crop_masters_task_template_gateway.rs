//! `CropMastersTaskTemplateGateway` — masters crop ↔ agricultural task template CRUD (create path).

use crate::crop::crop_gateway::{parse_required_tools_json, required_tools_to_json};
use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::CropTaskTemplatePersistAttributes;
use agrr_domain::crop::entities::CropTaskTemplateEntity;
use agrr_domain::crop::gateways::CropMastersTaskTemplateGateway;
use agrr_domain::shared::exceptions::RecordInvalidError;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use rusqlite::params;
use rust_decimal::Decimal;

pub struct CropMastersTaskTemplateSqliteGateway {
    pool: SqlitePool,
}

impl CropMastersTaskTemplateSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn map_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<CropTaskTemplateEntity> {
        let time_raw: Option<f64> = row.get(5)?;
        Ok(CropTaskTemplateEntity {
            id: row.get(0)?,
            crop_id: row.get(1)?,
            agricultural_task_id: row.get(2)?,
            name: row.get(3)?,
            description: row.get(4)?,
            time_per_sqm: time_raw.and_then(Decimal::from_f64_retain),
            weather_dependency: row.get(6)?,
            required_tools: parse_required_tools_json(row.get(7)?),
            skill_level: row.get(8)?,
            created_at: row.get(9)?,
            updated_at: row.get(10)?,
        })
    }

    const SELECT_COLS: &'static str =
        "id, crop_id, agricultural_task_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, created_at, updated_at";
}

impl CropMastersTaskTemplateGateway for CropMastersTaskTemplateSqliteGateway {
    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<Option<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!(
            "SELECT {} FROM crop_task_templates WHERE agricultural_task_id = ?1 AND crop_id = ?2",
            Self::SELECT_COLS
        );
        match self.pool.with_read_box(|conn| {
            conn.query_row(&sql, params![agricultural_task_id, crop_id], Self::map_entity)
        }) {
            Ok(entity) => Ok(Some(entity)),
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => Ok(None),
            Err(e) => Err(e),
        }
    }

    fn create_detail(
        &self,
        crop_id: i64,
        agricultural_task_id: i64,
        attributes: CropTaskTemplatePersistAttributes,
    ) -> Result<CropTaskTemplateEntity, Box<dyn std::error::Error + Send + Sync>> {
        if attributes.name.trim().is_empty() {
            return Err(Box::new(RecordInvalidError::new(
                Some("Name can't be blank".into()),
                None,
            )));
        }
        if let Some(t) = attributes.time_per_sqm {
            if t <= Decimal::ZERO {
                return Err(Box::new(RecordInvalidError::new(
                    Some("Time per sqm must be greater than 0".into()),
                    None,
                )));
            }
        }
        let time_f64 = attributes
            .time_per_sqm
            .and_then(|d| d.to_string().parse::<f64>().ok());
        let tools_json = required_tools_to_json(&attributes.required_tools);
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO crop_task_templates (crop_id, agricultural_task_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, datetime('now'), datetime('now'))",
                params![
                    crop_id,
                    agricultural_task_id,
                    attributes.name,
                    attributes.description,
                    time_f64,
                    attributes.weather_dependency,
                    tools_json,
                    attributes.skill_level,
                ],
            )?;
            let id = conn.last_insert_rowid();
            let sql = format!(
                "SELECT {} FROM crop_task_templates WHERE id = ?1",
                Self::SELECT_COLS
            );
            conn.query_row(&sql, params![id], Self::map_entity)
        })
    }
}
