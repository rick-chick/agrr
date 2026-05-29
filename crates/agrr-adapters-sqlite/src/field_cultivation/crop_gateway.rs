//! Crop read port for field cultivation climate.

use crate::pool::SqlitePool;
use agrr_domain::field_cultivation::dtos::{
    ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement, ClimateThermalRequirement,
};
use agrr_domain::field_cultivation::gateways::FieldCultivationCropGateway;
use rusqlite::{params, Connection};

pub struct FieldCultivationCropSqliteGateway {
    pool: SqlitePool,
}

impl FieldCultivationCropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn load_crop_stages(
    conn: &Connection,
    crop_id: i64,
) -> Result<Vec<ClimateCropStage>, rusqlite::Error> {
    let mut stmt = conn.prepare(
        "SELECT cs.name, cs.\"order\", \
         tr.base_temperature, tr.optimal_min, tr.optimal_max, tr.low_stress_threshold, \
         tr.high_stress_threshold, th.required_gdd \
         FROM crop_stages cs \
         LEFT JOIN temperature_requirements tr ON tr.crop_stage_id = cs.id \
         LEFT JOIN thermal_requirements th ON th.crop_stage_id = cs.id \
         WHERE cs.crop_id = ?1 ORDER BY cs.\"order\"",
    )?;
    let rows = stmt.query_map(params![crop_id], |row| {
        let name: String = row.get(0)?;
        let order: i32 = row.get(1)?;
        let base_temperature: Option<f64> = row.get(2)?;
        let optimal_min: Option<f64> = row.get(3)?;
        let optimal_max: Option<f64> = row.get(4)?;
        let low_stress: Option<f64> = row.get(5)?;
        let high_stress: Option<f64> = row.get(6)?;
        let required_gdd: Option<f64> = row.get(7)?;
        let (Some(base_temperature), Some(required_gdd)) = (base_temperature, required_gdd) else {
            return Ok(None);
        };
        Ok(Some(ClimateCropStage {
            name,
            order,
            temperature_requirement: Some(ClimateTemperatureRequirement {
                base_temperature,
                optimal_min,
                optimal_max,
                low_stress_threshold: low_stress,
                high_stress_threshold: high_stress,
            }),
            thermal_requirement: Some(ClimateThermalRequirement {
                required_gdd,
            }),
        }))
    })?;
    let mut stages = Vec::new();
    for row in rows {
        if let Some(stage) = row? {
            stages.push(stage);
        }
    }
    Ok(stages)
}

impl FieldCultivationCropGateway for FieldCultivationCropSqliteGateway {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<ClimateCropEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let (is_reference, user_id): (i64, Option<i64>) = conn.query_row(
                "SELECT is_reference, user_id FROM crops WHERE id = ?1",
                params![crop_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )?;
            let crop_stages = load_crop_stages(conn, crop_id)?;
            Ok(ClimateCropEntity {
                id: crop_id,
                is_reference: is_reference != 0,
                user_id,
                crop_stages,
            })
        })
    }
}
