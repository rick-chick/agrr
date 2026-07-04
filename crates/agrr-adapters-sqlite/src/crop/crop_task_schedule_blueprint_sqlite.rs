//! Shared SQLite helpers for `crop_task_schedule_blueprints`.

use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
};
use agrr_domain::shared::exceptions::RecordNotFoundError;
use rusqlite::params;
use rust_decimal::Decimal;
use serde_json::Value;

pub fn map_blueprint_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<MastersCropTaskScheduleBlueprint> {
    let gdd_trigger: f64 = row.get(6)?;
    let gdd_tolerance: Option<f64> = row.get(7)?;
    let amount: Option<f64> = row.get(11)?;
    let time_per_sqm: Option<f64> = row.get(14)?;
    Ok(MastersCropTaskScheduleBlueprint {
        id: row.get(0)?,
        crop_id: row.get(1)?,
        agricultural_task_id: row.get(2)?,
        source_agricultural_task_id: row.get(3)?,
        stage_order: row.get(4)?,
        stage_name: row.get(5)?,
        gdd_trigger: Decimal::from_str_exact(&gdd_trigger.to_string())
            .unwrap_or_else(|_| Decimal::ZERO),
        gdd_tolerance: gdd_tolerance
            .and_then(|v| Decimal::from_str_exact(&v.to_string()).ok()),
        task_type: row.get(8)?,
        source: row.get(9)?,
        priority: row.get(10)?,
        amount: amount.and_then(|v| Decimal::from_str_exact(&v.to_string()).ok()),
        amount_unit: row.get(12)?,
        description: row.get(13)?,
        weather_dependency: row.get(15)?,
        time_per_sqm: time_per_sqm
            .and_then(|v| Decimal::from_str_exact(&v.to_string()).ok()),
        name: row.get(16)?,
        created_at: row.get(17)?,
        updated_at: row.get(18)?,
    })
}

const SELECT_COLS: &str = "id, crop_id, agricultural_task_id, source_agricultural_task_id, \
    stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, amount, \
    amount_unit, description, time_per_sqm, weather_dependency, name, created_at, updated_at";

pub fn list_blueprints_by_crop_id(
    pool: &SqlitePool,
    crop_id: i64,
) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
    let sql = format!(
        "SELECT {SELECT_COLS} FROM crop_task_schedule_blueprints WHERE crop_id = ?1 ORDER BY stage_order, id"
    );
    pool.with_read_box(|conn| {
        let mut stmt = conn.prepare(&sql)?;
        let rows = stmt.query_map(params![crop_id], map_blueprint_entity)?;
        rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
    })
}

pub fn delete_blueprint_by_id(
    pool: &SqlitePool,
    crop_id: i64,
    blueprint_id: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    match pool.with_write_box(|conn| {
        conn.execute(
            "DELETE FROM crop_task_schedule_blueprints WHERE id = ?1 AND crop_id = ?2",
            params![blueprint_id, crop_id],
        )
    }) {
        Ok(0) => Err(Box::new(RecordNotFoundError)),
        Ok(_) => Ok(()),
        Err(e) => Err(e),
    }
}

pub fn delete_all_blueprints_for_crop(
    pool: &SqlitePool,
    crop_id: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    pool.with_write_box(|conn| {
        conn.execute(
            "DELETE FROM crop_task_schedule_blueprints WHERE crop_id = ?1",
            params![crop_id],
        )?;
        Ok(())
    })
}

pub fn bulk_insert_blueprints(
    pool: &SqlitePool,
    records: &[CropTaskScheduleBlueprintPersistAttrs],
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if records.is_empty() {
        return Ok(());
    }
    pool.with_write_box(|conn| {
        for rec in records {
            conn.execute(
                "INSERT INTO crop_task_schedule_blueprints (crop_id, agricultural_task_id, source_agricultural_task_id, \
                 stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, amount, amount_unit, \
                 description, weather_dependency, time_per_sqm, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, datetime('now'), datetime('now'))",
                params![
                    rec.crop_id,
                    rec.agricultural_task_id,
                    rec.source_agricultural_task_id,
                    rec.stage_order,
                    rec.stage_name,
                    rec.gdd_trigger,
                    rec.gdd_tolerance,
                    rec.task_type,
                    rec.source,
                    rec.priority,
                    rec.amount,
                    rec.amount_unit,
                    rec.description,
                    rec.weather_dependency,
                    rec.time_per_sqm,
                ],
            )?;
        }
        Ok(())
    })
}

pub fn update_blueprint(
    pool: &SqlitePool,
    crop_id: i64,
    blueprint_id: i64,
    attributes: Value,
) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
    let exists = pool.with_read_box(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM crop_task_schedule_blueprints WHERE id = ?1 AND crop_id = ?2",
            params![blueprint_id, crop_id],
            |row| row.get::<_, i64>(0),
        )
    })?;
    if exists == 0 {
        return Err(Box::new(RecordNotFoundError));
    }

    pool.with_write_box(|conn| {
        let stage_order = attributes.get("stage_order").and_then(|v| v.as_i64());
        let stage_name = attributes.get("stage_name").and_then(|v| v.as_str());
        let gdd_trigger = attributes
            .get("gdd_trigger")
            .map(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok())));
        let gdd_tolerance = attributes
            .get("gdd_tolerance")
            .map(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok())));
        let priority = attributes.get("priority").and_then(|v| v.as_i64());
        let amount = attributes
            .get("amount")
            .map(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok())));
        let amount_unit = attributes.get("amount_unit").and_then(|v| v.as_str());
        let description = attributes.get("description").and_then(|v| v.as_str());
        let weather_dependency = attributes.get("weather_dependency").and_then(|v| v.as_str());
        let time_per_sqm = attributes
            .get("time_per_sqm")
            .map(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok())));
        let name = attributes.get("name").and_then(|v| v.as_str());

        conn.execute(
            "UPDATE crop_task_schedule_blueprints SET \
             stage_order = COALESCE(?3, stage_order), \
             stage_name = COALESCE(?4, stage_name), \
             gdd_trigger = COALESCE(?5, gdd_trigger), \
             gdd_tolerance = COALESCE(?6, gdd_tolerance), \
             priority = COALESCE(?7, priority), \
             amount = COALESCE(?8, amount), \
             amount_unit = COALESCE(?9, amount_unit), \
             description = COALESCE(?10, description), \
             weather_dependency = COALESCE(?11, weather_dependency), \
             time_per_sqm = COALESCE(?12, time_per_sqm), \
             name = COALESCE(?13, name), \
             updated_at = datetime('now') \
             WHERE id = ?1 AND crop_id = ?2",
            params![
                blueprint_id,
                crop_id,
                stage_order,
                stage_name,
                gdd_trigger,
                gdd_tolerance,
                priority,
                amount,
                amount_unit,
                description,
                weather_dependency,
                time_per_sqm,
                name,
            ],
        )?;

        let sql = format!(
            "SELECT {SELECT_COLS} FROM crop_task_schedule_blueprints WHERE id = ?1"
        );
        conn.query_row(&sql, params![blueprint_id], map_blueprint_entity)
    })
}

pub fn insert_blueprint(
    pool: &SqlitePool,
    rec: &CropTaskScheduleBlueprintPersistAttrs,
) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
    let blueprint_id = pool.with_write_box(|conn| {
        conn.execute(
            "INSERT INTO crop_task_schedule_blueprints (crop_id, agricultural_task_id, source_agricultural_task_id, \
             stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, amount, amount_unit, \
             description, weather_dependency, time_per_sqm, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, datetime('now'), datetime('now'))",
            params![
                rec.crop_id,
                rec.agricultural_task_id,
                rec.source_agricultural_task_id,
                rec.stage_order,
                rec.stage_name,
                rec.gdd_trigger,
                rec.gdd_tolerance,
                rec.task_type,
                rec.source,
                rec.priority,
                rec.amount,
                rec.amount_unit,
                rec.description,
                rec.weather_dependency,
                rec.time_per_sqm,
            ],
        )?;
        Ok(conn.last_insert_rowid())
    })?;

    let sql = format!(
        "SELECT {SELECT_COLS} FROM crop_task_schedule_blueprints WHERE id = ?1 AND crop_id = ?2"
    );
    pool.with_read_box(|conn| {
        conn.query_row(&sql, params![blueprint_id, rec.crop_id], map_blueprint_entity)
            .map_err(Into::into)
    })
}

pub fn replace_all_blueprints_for_crop(
    pool: &SqlitePool,
    crop_id: i64,
    records: &[CropTaskScheduleBlueprintPersistAttrs],
) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
    delete_all_blueprints_for_crop(pool, crop_id)?;
    bulk_insert_blueprints(pool, records)?;
    list_blueprints_by_crop_id(pool, crop_id)
}
