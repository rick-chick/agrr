//! Load weather DTOs for cultivation-plan REST / optimization (Ruby AR preload parity).

use agrr_adapters_sqlite::cultivation_plan::planning_horizon::derive_planning_horizon;
use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::dtos::{
    CultivationPlanWeather, PredictedWeatherScope, WeatherLocation,
};
use agrr_domain::weather_data::gateways::PredictedWeatherMetadataGateway;
use std::sync::Arc;
use time::OffsetDateTime;

pub(crate) fn load_weather_location(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<WeatherLocation, String> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone \
             FROM cultivation_plans cp \
             INNER JOIN farms f ON f.id = cp.farm_id \
             INNER JOIN weather_locations wl ON wl.id = f.weather_location_id \
             WHERE cp.id = ?1",
            rusqlite::params![plan_id],
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
    })
    .map_err(|e| e.to_string())
}

pub(crate) fn load_plan_weather(
    pool: &SqlitePool,
    metadata: &Arc<dyn PredictedWeatherMetadataGateway>,
    plan_id: i64,
) -> Result<CultivationPlanWeather, String> {
    let today = OffsetDateTime::now_utc().date();
    let horizon = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT cp.plan_type, cp.plan_year, cp.planning_start_date, cp.planning_end_date, \
                 (SELECT MIN(fc.start_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 (SELECT MAX(fc.completion_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id) \
                 FROM cultivation_plans cp WHERE cp.id = ?1",
                rusqlite::params![plan_id],
                |row| {
                    let plan_type: String = row.get(0)?;
                    let plan_year: Option<i32> = row.get(1)?;
                    let planning_start: Option<String> = row.get(2)?;
                    let planning_end: Option<String> = row.get(3)?;
                    let fc_min: Option<String> = row.get(4)?;
                    let fc_max: Option<String> = row.get(5)?;
                    Ok(derive_planning_horizon(
                        &plan_type,
                        plan_year,
                        planning_start.as_deref(),
                        planning_end.as_deref(),
                        fc_min.as_deref(),
                        fc_max.as_deref(),
                        today,
                    ))
                },
            )
        })
        .map_err(|e| e.to_string())?;

    let plan_metadata = metadata
        .find(PredictedWeatherScope::Plan, plan_id)
        .map_err(|e| e.to_string())?;

    Ok(CultivationPlanWeather::new(
        plan_id,
        horizon.prediction_target_end_date,
        horizon.calculated_planning_end_date,
        plan_metadata,
    ))
}
