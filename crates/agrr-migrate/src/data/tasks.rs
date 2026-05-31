use super::context::{self, extracted_data_dir};
use anyhow::Context;
use rusqlite::{params, Connection};
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize)]
struct TasksFile {
    tasks: Vec<TaskRow>,
}

#[derive(Debug, Deserialize)]
struct TaskRow {
    name: String,
    description: String,
    time_per_sqm: f64,
    weather_dependency: String,
    required_tools: Vec<String>,
    skill_level: String,
}

pub fn apply(conn: &mut Connection, app_root: &Path, region: &str) -> anyhow::Result<()> {
    let path = extracted_data_dir(app_root).join(format!("tasks/{region}.json"));
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("read tasks fixture {}", path.display()))?;
    let file: TasksFile = serde_json::from_str(&text)?;
    let now = context::now_rfc3339();

    context::with_transaction(conn, |tx| {
        for task in &file.tasks {
            let tools_json = serde_json::to_string(&task.required_tools)?;
            let existing: Option<i64> = tx
                .query_row(
                    "SELECT id FROM agricultural_tasks WHERE name = ?1 AND region = ?2 AND is_reference = 1",
                    params![task.name, region],
                    |r| r.get(0),
                )
                .optional()
                .ok()
                .flatten();

            if let Some(id) = existing {
                tx.execute(
                    "UPDATE agricultural_tasks SET description = ?1, time_per_sqm = ?2, weather_dependency = ?3,
                     required_tools = ?4, skill_level = ?5, updated_at = ?6 WHERE id = ?7",
                    params![
                        task.description,
                        task.time_per_sqm,
                        task.weather_dependency,
                        tools_json,
                        task.skill_level,
                        now,
                        id
                    ],
                )?;
            } else {
                tx.execute(
                    "INSERT INTO agricultural_tasks (name, description, time_per_sqm, weather_dependency, required_tools,
                     skill_level, is_reference, user_id, region, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, NULL, ?7, ?8, ?8)",
                    params![
                        task.name,
                        task.description,
                        task.time_per_sqm,
                        task.weather_dependency,
                        tools_json,
                        task.skill_level,
                        region,
                        now
                    ],
                )?;
            }
        }
        Ok(())
    })?;

    println!(
        "  tasks/{region}: {} agricultural_tasks upserted",
        file.tasks.len()
    );
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
