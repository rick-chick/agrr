//! Build agrr `crop-requirement` JSON from SQLite (Ruby `CropAgrrRequirementMapper`).

use crate::pool::SqlitePool;
use rusqlite::params;
use serde_json::{json, Value};

pub fn build_crop_agrr_requirement(
    pool: &SqlitePool,
    crop_id: i64,
) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
    pool.with_read_box(|conn| {
        let (name, variety, area_per_unit, revenue_per_area, groups): (
            String,
            Option<String>,
            Option<f64>,
            Option<f64>,
            Option<String>,
        ) = conn.query_row(
            "SELECT name, variety, area_per_unit, revenue_per_area, groups FROM crops WHERE id = ?1",
            params![crop_id],
            |row| {
                Ok((
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            },
        )?;

        let stage_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM crop_stages WHERE crop_id = ?1",
            params![crop_id],
            |row| row.get(0),
        )?;
        if stage_count == 0 {
            return Ok(None);
        }

        let mut stmt = conn.prepare(
            "SELECT cs.name, cs.\"order\", \
             tr.base_temperature, tr.optimal_min, tr.optimal_max, tr.low_stress_threshold, \
             tr.high_stress_threshold, tr.frost_threshold, tr.max_temperature, \
             th.required_gdd \
             FROM crop_stages cs \
             LEFT JOIN temperature_requirements tr ON tr.crop_stage_id = cs.id \
             LEFT JOIN thermal_requirements th ON th.crop_stage_id = cs.id \
             WHERE cs.crop_id = ?1 ORDER BY cs.\"order\"",
        )?;
        let rows = stmt.query_map(params![crop_id], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, i32>(1)?,
                row.get::<_, Option<f64>>(2)?,
                row.get::<_, Option<f64>>(3)?,
                row.get::<_, Option<f64>>(4)?,
                row.get::<_, Option<f64>>(5)?,
                row.get::<_, Option<f64>>(6)?,
                row.get::<_, Option<f64>>(7)?,
                row.get::<_, Option<f64>>(8)?,
                row.get::<_, Option<f64>>(9)?,
            ))
        })?;

        let mut stage_requirements = Vec::new();
        for row in rows {
            let (
                stage_name,
                order,
                base_temperature,
                optimal_min,
                optimal_max,
                low_stress,
                high_stress,
                frost_threshold,
                max_temperature,
                required_gdd,
            ) = row?;
            let (Some(base_temperature), Some(required_gdd)) = (base_temperature, required_gdd) else {
                continue;
            };
            let stage_hash = json!({
                "stage": { "name": stage_name, "order": order },
                "temperature": {
                    "base_temperature": base_temperature,
                    "optimal_min": optimal_min,
                    "optimal_max": optimal_max,
                    "low_stress_threshold": low_stress,
                    "high_stress_threshold": high_stress,
                    "frost_threshold": frost_threshold,
                    "max_temperature": max_temperature.unwrap_or(50.0)
                },
                "thermal": { "required_gdd": required_gdd }
            });
            stage_requirements.push(stage_hash);
        }

        if stage_requirements.is_empty() {
            return Ok(None);
        }

        let groups: Value = groups
            .and_then(|g| serde_json::from_str(&g).ok())
            .unwrap_or_else(|| Value::Array(vec![]));
        let revenue = revenue_per_area.unwrap_or(5000.0);
        Ok(Some(json!({
            "crop": {
                "crop_id": crop_id.to_string(),
                "name": name,
                "variety": variety.unwrap_or_else(|| "general".into()),
                "area_per_unit": area_per_unit.unwrap_or(0.25),
                "revenue_per_area": revenue,
                "max_revenue": revenue * 100.0,
                "groups": groups
            },
            "stage_requirements": stage_requirements
        })))
    })
}

pub fn crop_stage_count(
    pool: &SqlitePool,
    crop_id: i64,
) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
    pool.with_read_box(|conn| {
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM crop_stages WHERE crop_id = ?1",
            params![crop_id],
            |row| row.get(0),
        )?;
        Ok(count as i32)
    })
}
