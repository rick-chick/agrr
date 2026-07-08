use super::context::{
    self, agricultural_task_id_by_name, crop_id_by_name, extracted_data_dir, with_transaction,
};
use anyhow::Context;
use rusqlite::{params, Connection};
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize)]
struct TemplatesFile {
    templates: Vec<TemplateRow>,
}

#[derive(Debug, Deserialize)]
struct TemplateRow {
    task_name: String,
    crop_name: String,
    description: String,
    time_per_sqm: f64,
    weather_dependency: String,
    required_tools: Vec<String>,
    skill_level: String,
}

pub fn apply(conn: &mut Connection, app_root: &Path, region: &str) -> anyhow::Result<()> {
    anyhow::ensure!(region == "jp", "templates only supported for jp");
    let path = extracted_data_dir(app_root).join("templates/jp.json");
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("read templates fixture {}", path.display()))?;
    let file: TemplatesFile = serde_json::from_str(&text)?;
    let now = context::now_rfc3339();
    let mut applied = 0usize;

    with_transaction(conn, |tx| {
        for row in &file.templates {
            let Some(crop_id) = crop_id_by_name(tx, &row.crop_name, region)? else {
                continue;
            };
            let Some(task_id) = agricultural_task_id_by_name(tx, &row.task_name, region)? else {
                continue;
            };

            let existing: Option<i64> = tx
                .query_row(
                    "SELECT id FROM crop_task_schedule_blueprints
                     WHERE crop_id = ?1 AND agricultural_task_id = ?2
                       AND source = 'manual' AND stage_order IS NULL AND gdd_trigger IS NULL",
                    params![crop_id, task_id],
                    |r| r.get(0),
                )
                .optional()
                .ok()
                .flatten();

            if let Some(id) = existing {
                tx.execute(
                    "UPDATE crop_task_schedule_blueprints
                     SET description = ?1, time_per_sqm = ?2, weather_dependency = ?3,
                         name = ?4, updated_at = ?5
                     WHERE id = ?6",
                    params![
                        row.description,
                        row.time_per_sqm,
                        row.weather_dependency,
                        row.task_name,
                        now,
                        id
                    ],
                )?;
            } else {
                tx.execute(
                    "INSERT INTO crop_task_schedule_blueprints (
                        crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger,
                        gdd_tolerance, task_type, source, priority, description, weather_dependency,
                        time_per_sqm, name, created_at, updated_at
                     ) VALUES (
                        ?1, ?2, NULL, NULL, NULL, NULL, 'field_work', 'manual', 1,
                        ?3, ?4, ?5, ?6, ?7, ?7
                     )",
                    params![
                        crop_id,
                        task_id,
                        row.description,
                        row.weather_dependency,
                        row.time_per_sqm,
                        row.task_name,
                        now
                    ],
                )?;
            }
            applied += 1;
        }
        Ok(())
    })?;

    println!("  templates/jp: {applied} manual blueprints upserted");
    Ok(())
}

trait OptionalRow {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error>;
}

impl OptionalRow for Result<i64, rusqlite::Error> {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}
