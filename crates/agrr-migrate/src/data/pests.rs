use super::context::{self, crop_id_resolve, extracted_data_dir};
use anyhow::Context;
use rusqlite::{params, Connection, Transaction};
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize)]
struct PestsFile {
    pests: Vec<PestRow>,
}

#[derive(Debug, Deserialize)]
struct PestRow {
    name: String,
    name_scientific: Option<String>,
    family: Option<String>,
    order: Option<String>,
    description: Option<String>,
    occurrence_season: Option<String>,
    temperature_profile: Option<TempProfile>,
    thermal_requirement: Option<ThermalReq>,
    control_methods: Vec<ControlMethod>,
    crop_names: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct TempProfile {
    base_temperature: f64,
    max_temperature: f64,
}

#[derive(Debug, Deserialize)]
struct ThermalReq {
    required_gdd: f64,
    first_generation_gdd: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct ControlMethod {
    method_type: String,
    method_name: String,
    description: Option<String>,
    timing_hint: Option<String>,
}

pub fn apply(conn: &mut Connection, app_root: &Path, region: &str) -> anyhow::Result<()> {
    let path = extracted_data_dir(app_root).join(format!("pests/{region}.json"));
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("read pests fixture {}", path.display()))?;
    let file: PestsFile = serde_json::from_str(&text)?;
    let now = context::now_rfc3339();

    context::with_transaction(conn, |tx| {
        for pest in &file.pests {
            upsert_pest(tx, region, pest, &now)?;
        }
        Ok(())
    })?;

    println!("  pests/{region}: {} pests upserted", file.pests.len());
    Ok(())
}

fn upsert_pest(
    tx: &Transaction<'_>,
    region: &str,
    pest: &PestRow,
    now: &str,
) -> anyhow::Result<()> {
    let pest_id: i64 = if let Some(id) = tx
        .query_row(
            "SELECT id FROM pests WHERE name = ?1 AND region = ?2 AND is_reference = 1",
            params![pest.name, region],
            |r| r.get(0),
        )
        .ok()
    {
        tx.execute(
            "UPDATE pests SET name_scientific = ?1, family = ?2, \"order\" = ?3, description = ?4,
             occurrence_season = ?5, updated_at = ?6 WHERE id = ?7",
            params![
                pest.name_scientific,
                pest.family,
                pest.order,
                pest.description,
                pest.occurrence_season,
                now,
                id
            ],
        )?;
        id
    } else {
        tx.execute(
            "INSERT INTO pests (name, name_scientific, family, \"order\", description, occurrence_season,
             is_reference, user_id, region, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, NULL, ?7, ?8, ?8)",
            params![
                pest.name,
                pest.name_scientific,
                pest.family,
                pest.order,
                pest.description,
                pest.occurrence_season,
                region,
                now
            ],
        )?;
        tx.last_insert_rowid()
    };

    if let Some(tp) = &pest.temperature_profile {
        let exists: i64 = tx.query_row(
            "SELECT COUNT(*) FROM pest_temperature_profiles WHERE pest_id = ?1",
            params![pest_id],
            |r| r.get(0),
        )?;
        if exists == 0 {
            tx.execute(
                "INSERT INTO pest_temperature_profiles (pest_id, base_temperature, max_temperature, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?4)",
                params![pest_id, tp.base_temperature, tp.max_temperature, now],
            )?;
        }
    }

    if let Some(tr) = &pest.thermal_requirement {
        let exists: i64 = tx.query_row(
            "SELECT COUNT(*) FROM pest_thermal_requirements WHERE pest_id = ?1",
            params![pest_id],
            |r| r.get(0),
        )?;
        if exists == 0 {
            tx.execute(
                "INSERT INTO pest_thermal_requirements (pest_id, required_gdd, first_generation_gdd, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?4)",
                params![pest_id, tr.required_gdd, tr.first_generation_gdd, now],
            )?;
        }
    }

    tx.execute(
        "DELETE FROM pest_control_methods WHERE pest_id = ?1",
        params![pest_id],
    )?;
    for cm in &pest.control_methods {
        tx.execute(
            "INSERT INTO pest_control_methods (pest_id, method_type, method_name, description, timing_hint, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
            params![
                pest_id,
                cm.method_type,
                cm.method_name,
                cm.description,
                cm.timing_hint,
                now
            ],
        )?;
    }

    for crop_ref in &pest.crop_names {
        if let Some(crop_id) = crop_id_resolve(tx, crop_ref, region)? {
            let n: i64 = tx.query_row(
                "SELECT COUNT(*) FROM crop_pests WHERE crop_id = ?1 AND pest_id = ?2",
                params![crop_id, pest_id],
                |r| r.get(0),
            )?;
            if n == 0 {
                tx.execute(
                    "INSERT INTO crop_pests (crop_id, pest_id, created_at, updated_at) VALUES (?1, ?2, ?3, ?3)",
                    params![crop_id, pest_id, now],
                )?;
            }
        }
    }

    Ok(())
}
