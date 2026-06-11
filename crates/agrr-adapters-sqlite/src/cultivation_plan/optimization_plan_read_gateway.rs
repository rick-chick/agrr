//! Ruby: `OptimizationPlanReadActiveRecordGateway`

use crate::cultivation_plan::planning_horizon::derive_planning_horizon;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::OptimizationPlanReadPlanCoreSnapshot;
use agrr_domain::cultivation_plan::gateways::OptimizationPlanReadGateway;
use agrr_domain::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope, WeatherLocation};
use agrr_domain::weather_data::gateways::PredictedWeatherMetadataGateway;
use rusqlite::{params, OptionalExtension};
use std::sync::Arc;
use time::OffsetDateTime;

pub struct OptimizationPlanReadSqliteGateway {
    pool: SqlitePool,
    metadata: Arc<dyn PredictedWeatherMetadataGateway>,
}

impl OptimizationPlanReadSqliteGateway {
    pub fn new(pool: SqlitePool, metadata: Arc<dyn PredictedWeatherMetadataGateway>) -> Self {
        Self { pool, metadata }
    }
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
                 cp.total_area, f.weather_location_id \
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
                    let wl_id: Option<i64> = row.get(8)?;
                    Ok(OptimizationPlanReadPlanCoreSnapshot {
                        plan_id: row.get(0)?,
                        plan_type_private: plan_type == "private",
                        calculated_planning_start_date: horizon.calculated_planning_start_date,
                        calculated_planning_end_date: horizon.calculated_planning_end_date,
                        prediction_target_end_date: horizon.prediction_target_end_date,
                        plan_metadata: None,
                        total_area: row.get(7)?,
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
                    "SELECT wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone \
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
                        ))
                    },
                )
                .optional()?;
            Ok(row)
        })
    }

    fn find_optimization_plan_metadata_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>> {
        self.metadata.find(PredictedWeatherScope::Plan, plan_id)
    }
}
