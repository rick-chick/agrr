//! Load weather DTOs for cultivation-plan REST / optimization (Ruby AR preload parity).

use agrr_adapters_sqlite::cultivation_plan::planning_horizon::derive_planning_horizon;
use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::dtos::{CultivationPlanWeather, FarmWeatherPrediction, WeatherLocation};
use serde_json::Value;
use time::OffsetDateTime;

pub(crate) fn load_weather_location(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<WeatherLocation, String> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone, wl.predicted_weather_data \
             FROM cultivation_plans cp \
             INNER JOIN farms f ON f.id = cp.farm_id \
             INNER JOIN weather_locations wl ON wl.id = f.weather_location_id \
             WHERE cp.id = ?1",
            rusqlite::params![plan_id],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, f64>(1)?,
                    row.get::<_, f64>(2)?,
                    row.get::<_, Option<f64>>(3)?,
                    row.get::<_, Option<String>>(4)?,
                    row.get::<_, Option<String>>(5)?,
                ))
            },
        )
    })
    .map_err(|e| e.to_string())
    .map(|(id, lat, lon, elev, tz, predicted_raw)| {
        let predicted = predicted_raw.and_then(|s| serde_json::from_str::<Value>(&s).ok());
        WeatherLocation::new(id, lat, lon, elev, tz, predicted)
    })
}

pub(crate) fn load_farm_weather_prediction(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<Option<FarmWeatherPrediction>, String> {
    let row = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT f.id, f.weather_location_id, f.predicted_weather_data \
                 FROM cultivation_plans cp \
                 INNER JOIN farms f ON f.id = cp.farm_id \
                 WHERE cp.id = ?1",
                rusqlite::params![plan_id],
                |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, i64>(1)?,
                        row.get::<_, Option<String>>(2)?,
                    ))
                },
            )
        })
        .map_err(|e| e.to_string());

    match row {
        Ok((id, wl_id, predicted_raw)) => {
            let predicted = predicted_raw.and_then(|s| serde_json::from_str::<Value>(&s).ok());
            Ok(Some(FarmWeatherPrediction::new(id, wl_id, predicted)))
        }
        Err(e) if e.contains("QueryReturnedNoRows") => Ok(None),
        Err(e) => Err(e),
    }
}

pub(crate) fn load_plan_weather(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<CultivationPlanWeather, String> {
    let today = OffsetDateTime::now_utc().date();
    let (horizon, predicted) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT cp.plan_type, cp.plan_year, cp.planning_start_date, cp.planning_end_date, \
                 (SELECT MIN(fc.start_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 (SELECT MAX(fc.completion_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 cp.predicted_weather_data \
                 FROM cultivation_plans cp WHERE cp.id = ?1",
                rusqlite::params![plan_id],
                |row| {
                    let plan_type: String = row.get(0)?;
                    let plan_year: Option<i32> = row.get(1)?;
                    let planning_start: Option<String> = row.get(2)?;
                    let planning_end: Option<String> = row.get(3)?;
                    let fc_min: Option<String> = row.get(4)?;
                    let fc_max: Option<String> = row.get(5)?;
                    let predicted: Option<String> = row.get(6)?;
                    let horizon = derive_planning_horizon(
                        &plan_type,
                        plan_year,
                        planning_start.as_deref(),
                        planning_end.as_deref(),
                        fc_min.as_deref(),
                        fc_max.as_deref(),
                        today,
                    );
                    Ok((horizon, predicted))
                },
            )
        })
        .map_err(|e| e.to_string())?;
    let predicted_json = predicted.and_then(|s: String| serde_json::from_str::<Value>(&s).ok());
    Ok(CultivationPlanWeather::new(
        plan_id,
        horizon.prediction_target_end_date,
        horizon.calculated_planning_end_date,
        predicted_json,
    ))
}
