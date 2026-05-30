//! Ruby: `OptimizationPlanReadActiveRecordGateway`

use crate::cultivation_plan::planning_horizon::derive_planning_horizon;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::OptimizationPlanReadPlanCoreSnapshot;
use agrr_domain::cultivation_plan::gateways::OptimizationPlanReadGateway;
use agrr_domain::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};
use rusqlite::{params, OptionalExtension};
use serde_json::Value;
use time::OffsetDateTime;

pub struct OptimizationPlanReadSqliteGateway {
    pool: SqlitePool,
}

impl OptimizationPlanReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn parse_json_opt(raw: Option<String>) -> Option<Value> {
    raw.and_then(|s| serde_json::from_str(&s).ok())
}

impl OptimizationPlanReadGateway for OptimizationPlanReadSqliteGateway {
    fn find_optimization_plan_core_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<OptimizationPlanReadPlanCoreSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let today = OffsetDateTime::now_utc().date();
            conn.query_row(
                "SELECT cp.id, cp.plan_type, cp.plan_year, cp.planning_start_date, \
                 cp.planning_end_date, \
                 (SELECT MIN(fc.start_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 (SELECT MAX(fc.completion_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 cp.predicted_weather_data, cp.total_area, f.weather_location_id \
                 FROM cultivation_plans cp \
                 LEFT JOIN farms f ON f.id = cp.farm_id \
                 WHERE cp.id = ?1",
                params![plan_id],
                |row| {
                    let plan_type: String = row.get(1)?;
                    let plan_year: Option<i32> = row.get(2)?;
                    let planning_start: Option<String> = row.get(3)?;
                    let planning_end: Option<String> = row.get(4)?;
                    let fc_min: Option<String> = row.get(5)?;
                    let fc_max: Option<String> = row.get(6)?;
                    let horizon = derive_planning_horizon(
                        &plan_type,
                        plan_year,
                        planning_start.as_deref(),
                        planning_end.as_deref(),
                        fc_min.as_deref(),
                        fc_max.as_deref(),
                        today,
                    );
                    let wl_id: Option<i64> = row.get(9)?;
                    Ok(OptimizationPlanReadPlanCoreSnapshot {
                        plan_id: row.get(0)?,
                        plan_type_private: plan_type == "private",
                        calculated_planning_start_date: horizon.calculated_planning_start_date,
                        calculated_planning_end_date: horizon.calculated_planning_end_date,
                        prediction_target_end_date: horizon.prediction_target_end_date,
                        predicted_weather_data: parse_json_opt(row.get(7)?),
                        total_area: row.get(8)?,
                        weather_location_present: wl_id.is_some(),
                    })
                },
            )
            .map_err(|e| e.into())
        })
    }

    fn find_optimization_weather_location_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<WeatherLocation>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let row = conn
                .query_row(
                    "SELECT wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone, wl.predicted_weather_data \
                     FROM cultivation_plans cp \
                     INNER JOIN farms f ON f.id = cp.farm_id \
                     INNER JOIN weather_locations wl ON wl.id = f.weather_location_id \
                     WHERE cp.id = ?1",
                    params![plan_id],
                    |row| {
                        Ok(WeatherLocation::new(
                            row.get(0)?,
                            row.get(1)?,
                            row.get(2)?,
                            row.get(3)?,
                            row.get(4)?,
                            parse_json_opt(row.get(5)?),
                        ))
                    },
                )
                .optional()?;
            Ok(row)
        })
    }

    fn find_optimization_farm_weather_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<FarmWeatherPrediction>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let row = conn
                .query_row(
                    "SELECT f.id, f.weather_location_id, f.predicted_weather_data \
                     FROM cultivation_plans cp \
                     INNER JOIN farms f ON f.id = cp.farm_id \
                     WHERE cp.id = ?1",
                    params![plan_id],
                    |row| {
                        Ok(FarmWeatherPrediction::new(
                            row.get(0)?,
                            row.get(1)?,
                            parse_json_opt(row.get(2)?),
                        ))
                    },
                )
                .optional()?;
            Ok(row)
        })
    }
}
