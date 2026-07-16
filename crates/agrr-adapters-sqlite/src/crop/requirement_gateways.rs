//! Read gateways for crop stage requirement records.

use crate::pool::SqlitePool;
use agrr_domain::crop::entities::{
    NutrientRequirementEntity, SunshineRequirementEntity, TemperatureRequirementEntity,
    ThermalRequirementEntity,
};
use agrr_domain::crop::gateways::{
    NutrientRequirementGateway, SunshineRequirementGateway, TemperatureRequirementGateway,
    ThermalRequirementGateway,
};
use rusqlite::params;
use rust_decimal::Decimal;

pub struct TemperatureRequirementSqliteGateway {
    pool: SqlitePool,
}

impl TemperatureRequirementSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn dec(v: Option<f64>) -> Option<Decimal> {
    v.and_then(Decimal::from_f64_retain)
}

fn map_temperature(row: &rusqlite::Row<'_>) -> rusqlite::Result<TemperatureRequirementEntity> {
    Ok(TemperatureRequirementEntity {
        id: row.get(0)?,
        crop_stage_id: row.get(1)?,
        base_temperature: dec(row.get(2)?),
        optimal_min: dec(row.get(3)?),
        optimal_max: dec(row.get(4)?),
        low_stress_threshold: dec(row.get(5)?),
        high_stress_threshold: dec(row.get(6)?),
        frost_threshold: dec(row.get(7)?),
        sterility_risk_threshold: dec(row.get(8)?),
        max_temperature: dec(row.get(9)?),
    })
}

impl TemperatureRequirementGateway for TemperatureRequirementSqliteGateway {
    fn find_by_crop_stage_id(
        &self,
        crop_stage_id: i64,
    ) -> Result<Option<TemperatureRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            match conn.query_row(
                "SELECT id, crop_stage_id, base_temperature, optimal_min, optimal_max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature \
                 FROM temperature_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
                map_temperature,
            ) {
                Ok(e) => Ok(Some(e)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e.into()),
            }
        })
    }
}

pub struct ThermalRequirementSqliteGateway {
    pool: SqlitePool,
}

impl ThermalRequirementSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl ThermalRequirementGateway for ThermalRequirementSqliteGateway {
    fn find_by_crop_stage_id(
        &self,
        crop_stage_id: i64,
    ) -> Result<Option<ThermalRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            match conn.query_row(
                "SELECT id, crop_stage_id, required_gdd FROM thermal_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
                |row| {
                    ThermalRequirementEntity::new(
                        row.get(0)?,
                        row.get(1)?,
                        dec(row.get(2)?),
                    )
                    .map_err(|e| {
                        rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                            std::io::ErrorKind::InvalidData,
                            e,
                        )))
                    })
                },
            ) {
                Ok(e) => Ok(Some(e)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e.into()),
            }
        })
    }
}

pub struct SunshineRequirementSqliteGateway {
    pool: SqlitePool,
}

impl SunshineRequirementSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl SunshineRequirementGateway for SunshineRequirementSqliteGateway {
    fn find_by_crop_stage_id(
        &self,
        crop_stage_id: i64,
    ) -> Result<Option<SunshineRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            match conn.query_row(
                "SELECT id, crop_stage_id, minimum_sunshine_hours, target_sunshine_hours FROM sunshine_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
                |row| {
                    Ok(SunshineRequirementEntity {
                        id: row.get(0)?,
                        crop_stage_id: row.get(1)?,
                        minimum_sunshine_hours: dec(row.get(2)?),
                        target_sunshine_hours: dec(row.get(3)?),
                    })
                },
            ) {
                Ok(e) => Ok(Some(e)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e.into()),
            }
        })
    }
}

pub struct NutrientRequirementSqliteGateway {
    pool: SqlitePool,
}

impl NutrientRequirementSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl NutrientRequirementGateway for NutrientRequirementSqliteGateway {
    fn find_by_crop_stage_id(
        &self,
        crop_stage_id: i64,
    ) -> Result<Option<NutrientRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            match conn.query_row(
                "SELECT id, crop_stage_id, daily_uptake_n, daily_uptake_p, daily_uptake_k, region FROM nutrient_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
                |row| {
                    Ok(NutrientRequirementEntity {
                        id: row.get(0)?,
                        crop_stage_id: row.get(1)?,
                        daily_uptake_n: dec(row.get(2)?),
                        daily_uptake_p: dec(row.get(3)?),
                        daily_uptake_k: dec(row.get(4)?),
                        region: row.get(5)?,
                    })
                },
            ) {
                Ok(e) => Ok(Some(e)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e.into()),
            }
        })
    }
}
