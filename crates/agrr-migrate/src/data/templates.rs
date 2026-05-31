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
            let tools_json = serde_json::to_string(&row.required_tools)?;

            let existing: Option<i64> = tx
                .query_row(
                    "SELECT id FROM crop_task_templates WHERE crop_id = ?1 AND name = ?2 AND is_reference = 1",
                    params![crop_id, row.task_name],
                    |r| r.get(0),
                )
                .optional()
                .ok()
                .flatten();

            if let Some(id) = existing {
                tx.execute(
                    "UPDATE crop_task_templates SET agricultural_task_id = ?1, description = ?2, time_per_sqm = ?3,
                     weather_dependency = ?4, required_tools = ?5, skill_level = ?6, updated_at = ?7 WHERE id = ?8",
                    params![
                        task_id,
                        row.description,
                        row.time_per_sqm,
                        row.weather_dependency,
                        tools_json,
                        row.skill_level,
                        now,
                        id
                    ],
                )?;
            } else {
                tx.execute(
                    "INSERT INTO crop_task_templates (crop_id, agricultural_task_id, name, description, time_per_sqm,
                     weather_dependency, required_tools, skill_level, is_reference, ai_state, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 1, 'pending', ?9, ?9)",
                    params![
                        crop_id,
                        task_id,
                        row.task_name,
                        row.description,
                        row.time_per_sqm,
                        row.weather_dependency,
                        tools_json,
                        row.skill_level,
                        now
                    ],
                )?;
            }
            applied += 1;
        }
        Ok(())
    })?;

    println!("  templates/jp: {applied} crop_task_templates upserted");
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
