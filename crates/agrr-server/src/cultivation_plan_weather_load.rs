//! Load weather DTOs for cultivation-plan REST / optimization (Ruby AR preload parity).

use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::dtos::{CultivationPlanWeather, FarmWeatherPrediction, WeatherLocation};
use serde_json::Value;
use time::Date;

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
    let (planning_end, predicted) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT planning_end_date, predicted_weather_data FROM cultivation_plans WHERE id = ?1",
                rusqlite::params![plan_id],
                |row| {
                    Ok((
                        row.get::<_, Option<String>>(0)?,
                        row.get::<_, Option<String>>(1)?,
                    ))
                },
            )
        })
        .map_err(|e| e.to_string())?;
    let parse = |s: Option<String>| {
        s.as_deref().and_then(|d| {
            Date::parse(d, &time::format_description::well_known::Iso8601::DATE).ok()
        })
    };
    let end = parse(planning_end);
    let predicted_json = predicted.and_then(|s: String| serde_json::from_str::<Value>(&s).ok());
    Ok(CultivationPlanWeather::new(plan_id, end, end, predicted_json))
}
