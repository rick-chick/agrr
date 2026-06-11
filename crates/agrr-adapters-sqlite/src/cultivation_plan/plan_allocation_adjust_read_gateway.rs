//! Ruby: `PlanAllocationAdjustReadActiveRecordGateway` + domain snapshot assembly.

use crate::crop::agrr_requirement::{build_crop_agrr_requirement, crop_stage_count};
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    PlanAllocationAdjustCultivationPeriod, PlanAllocationAdjustFieldCultivationSnapshot,
    PlanAllocationAdjustPlanFieldSnapshot, PlanAllocationAdjustPlanningBoundaries,
    PlanAllocationAdjustReadSnapshot,
};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustReadGateway;
use agrr_domain::cultivation_plan::mappers::PlanAllocationAdjustReadSnapshotParts;
use agrr_domain::field_cultivation::dtos::WeatherPredictionTargets;
use agrr_domain::weather_data::dtos::{
    CultivationPlanWeather, PredictedWeatherScope, WeatherLocation,
};
use agrr_domain::weather_data::gateways::{PredictedWeatherMetadataGateway, WeatherDataGateway};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;
use time::Date;

pub struct PlanAllocationAdjustReadSqliteGateway {
    pool: SqlitePool,
    weather_data: Arc<dyn WeatherDataGateway>,
    metadata: Arc<dyn PredictedWeatherMetadataGateway>,
}

impl PlanAllocationAdjustReadSqliteGateway {
    /// Ruby: `PlanAllocationAdjustReadActiveRecordGateway.new(weather_data_gateway: ...)`
    pub fn new(
        pool: SqlitePool,
        weather_data: Arc<dyn WeatherDataGateway>,
        metadata: Arc<dyn PredictedWeatherMetadataGateway>,
    ) -> Self {
        Self {
            pool,
            weather_data,
            metadata,
        }
    }
}

fn parse_date(s: &str) -> Option<Date> {
    let s = s.trim();
    if s.len() >= 10 {
        Date::parse(&s[..10], &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
    } else {
        None
    }
}

impl PlanAllocationAdjustReadGateway for PlanAllocationAdjustReadSqliteGateway {
    fn find_adjust_read_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<PlanAllocationAdjustReadSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let (
            plan_field_snapshots,
            field_cultivation_snapshots,
            crop_rows,
            header,
        ) = self.pool.with_read_box(move |conn| {
            let header = conn
                .query_row(
                    "SELECT cp.id, cp.planning_start_date, cp.planning_end_date, \
                     cp.planning_end_date AS prediction_target_end_date, \
                     cp.planning_end_date AS calculated_planning_end_date, \
                     f.id, f.name, f.latitude, f.longitude, \
                     wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone \
                     FROM cultivation_plans cp \
                     LEFT JOIN farms f ON f.id = cp.farm_id \
                     LEFT JOIN weather_locations wl ON wl.id = f.weather_location_id \
                     WHERE cp.id = ?1 LIMIT 1",
                    params![plan_id],
                    |row| {
                        Ok((
                            row.get::<_, i64>(0)?,
                            row.get::<_, Option<String>>(1)?,
                            row.get::<_, Option<String>>(2)?,
                            row.get::<_, Option<String>>(3)?,
                            row.get::<_, Option<String>>(4)?,
                            row.get::<_, Option<i64>>(5)?,
                            row.get::<_, Option<String>>(6)?,
                            row.get::<_, Option<f64>>(7)?,
                            row.get::<_, Option<f64>>(8)?,
                            row.get::<_, Option<i64>>(9)?,
                            row.get::<_, Option<f64>>(10)?,
                            row.get::<_, Option<f64>>(11)?,
                            row.get::<_, Option<f64>>(12)?,
                            row.get::<_, Option<String>>(13)?,
                        ))
                    },
                )
                .optional()?;
            let Some(header) = header else {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            };

            let plan_field_snapshots = load_plan_fields(conn, plan_id)?;
            let field_cultivation_snapshots = load_field_cultivations(conn, plan_id)?;
            let crop_rows = load_plan_crop_rows(conn, plan_id)?;
            Ok((
                plan_field_snapshots,
                field_cultivation_snapshots,
                crop_rows,
                header,
            ))
        })?;

        let plan_crop_snapshots = build_plan_crop_snapshots(&self.pool, crop_rows)?;

        let field_source_snapshots =
            PlanAllocationAdjustReadSnapshotParts::build_field_source_snapshots(
                &plan_field_snapshots,
                &field_cultivation_snapshots,
            );

        let cultivation_planning_periods: Vec<PlanAllocationAdjustCultivationPeriod> =
            field_cultivation_snapshots
                .iter()
                .map(|fc| PlanAllocationAdjustCultivationPeriod {
                    start_date: Some(fc.start_date),
                    completion_date: Some(fc.completion_date),
                })
                .collect();

        let (
                _plan_id,
                planning_start_date,
                planning_end_date,
                prediction_target_end_date,
                calculated_planning_end_date,
                _farm_id,
                farm_name,
                farm_lat,
                farm_lon,
                wl_id,
                wl_lat,
                wl_lon,
                wl_elevation,
                wl_timezone,
        ) = header;

        let planning_start = planning_start_date.as_deref().and_then(parse_date);
        let planning_end = planning_end_date.as_deref().and_then(parse_date);
        let prediction_target = prediction_target_end_date.as_deref().and_then(parse_date);
        let calculated_end = calculated_planning_end_date.as_deref().and_then(parse_date);
        let plan_metadata = self.metadata.find(PredictedWeatherScope::Plan, plan_id)?;

        let weather_location = match (wl_id, wl_lat, wl_lon) {
                (Some(id), Some(lat), Some(lon)) => {
                    let wl = WeatherLocation::new(
                        id,
                        lat,
                        lon,
                        wl_elevation,
                        wl_timezone,
                    );
                    let facts = PlanAllocationAdjustReadSnapshotParts::weather_location_facts(&wl);
                    Some((wl, facts))
                }
            _ => None,
        };

        let farm_without_weather_location = weather_location.is_none();
        let weather_location_facts: HashMap<String, Value> = weather_location
            .as_ref()
            .map(|(wl, _)| {
                PlanAllocationAdjustReadSnapshotParts::weather_location_facts(wl)
                    .into_iter()
                    .collect()
            })
            .unwrap_or_default();

        let weather_location_json = weather_location.as_ref().map(|(wl, _)| {
            json!({
                "id": wl.id,
                "latitude": wl.latitude,
                "longitude": wl.longitude,
                "elevation": wl.elevation,
                "timezone": wl.timezone
            })
        });

        let farm_json = json!({
            "id": _farm_id,
            "name": farm_name,
            "latitude": farm_lat,
            "longitude": farm_lon
        });

        Ok(PlanAllocationAdjustReadSnapshot {
            plan_id,
            field_source_snapshots,
            plan_field_snapshots,
            plan_crop_snapshots,
            cultivation_planning_periods,
            planning_period_boundaries: PlanAllocationAdjustPlanningBoundaries {
                planning_start_date: planning_start,
                planning_end_date: planning_end,
            },
            cultivation_plan_weather_dto: CultivationPlanWeather::new(
                plan_id,
                prediction_target,
                calculated_end,
                plan_metadata,
            ),
            weather_prediction_targets: WeatherPredictionTargets {
                weather_location: weather_location_json.clone().unwrap_or(Value::Null),
                farm: farm_json,
            },
            weather_location_facts,
            farm_without_weather_location,
        })
    }

    fn list_historical_weather_rows(
        &self,
        weather_location_id: Option<i64>,
        historical_start: Date,
        historical_end: Date,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>> {
        let Some(weather_location_id) = weather_location_id else {
            return Ok(vec![]);
        };
        let dtos = self
            .weather_data
            .weather_data_for_period(weather_location_id, historical_start, historical_end)
            .map_err(|e| -> Box<dyn std::error::Error + Send + Sync> { e.to_string().into() })?;
        let mut out = Vec::new();
        for dto in dtos {
            if dto.temperature_max.is_none() || dto.temperature_min.is_none() {
                continue;
            }
            out.push(json!({
                "date": dto.date.to_string(),
                "temperature_max": dto.temperature_max,
                "temperature_min": dto.temperature_min,
                "temperature_mean": dto.temperature_mean,
                "precipitation": dto.precipitation,
                "sunshine_hours": dto.sunshine_hours,
                "wind_speed": dto.wind_speed,
                "weather_code": dto.weather_code,
            }));
        }
        Ok(out)
    }

    fn plan_summary_for_adjust_response(
        &self,
        plan_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM field_cultivations WHERE cultivation_plan_id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(json!({
                "id": plan_id,
                "field_cultivations_count": count
            }))
        })
    }
}

fn load_plan_fields(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<Vec<PlanAllocationAdjustPlanFieldSnapshot>> {
    let mut stmt = conn.prepare(
        "SELECT id, name, COALESCE(area, 0), COALESCE(daily_fixed_cost, 0) \
         FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1 ORDER BY id",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok(PlanAllocationAdjustPlanFieldSnapshot::new(
            row.get(0)?,
            row.get::<_, String>(1)?,
            row.get(2)?,
            row.get(3)?,
        ))
    })?;
    rows.collect()
}

fn load_field_cultivations(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<Vec<PlanAllocationAdjustFieldCultivationSnapshot>> {
    let mut stmt = conn.prepare(
        "SELECT fc.id, fc.cultivation_plan_field_id, c.id, \
         COALESCE(cpc.name, c.name), cpc.variety, COALESCE(fc.area, 0), \
         fc.start_date, fc.completion_date, fc.cultivation_days, fc.estimated_cost, \
         fc.optimization_result, \
         (SELECT COUNT(*) FROM crop_stages WHERE crop_id = c.id) AS stage_count \
         FROM field_cultivations fc \
         INNER JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
         INNER JOIN crops c ON c.id = cpc.crop_id \
         WHERE fc.cultivation_plan_id = ?1 ORDER BY fc.id",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        let start_s: Option<String> = row.get(6)?;
        let end_s: Option<String> = row.get(7)?;
        let opt_result: Option<String> = row.get(10)?;
        Ok((
            row.get::<_, i64>(0)?,
            row.get::<_, i64>(1)?,
            row.get::<_, i64>(2)?,
            row.get::<_, String>(3)?,
            row.get::<_, Option<String>>(4)?,
            row.get::<_, f64>(5)?,
            start_s,
            end_s,
            row.get::<_, Option<i32>>(8)?,
            row.get::<_, Option<f64>>(9)?,
            opt_result,
            row.get::<_, i64>(11)?,
        ))
    })?;

    let mut out = Vec::new();
    for row in rows {
        let (
            fc_id,
            field_id,
            crop_id,
            crop_name,
            variety,
            area,
            start_s,
            end_s,
            cultivation_days,
            estimated_cost,
            opt_result,
            stage_count,
        ) = row?;
        let (Some(start_s), Some(end_s)) = (start_s, end_s) else {
            continue;
        };
        let Some(start_date) = parse_date(&start_s) else {
            continue;
        };
        let Some(completion_date) = parse_date(&end_s) else {
            continue;
        };
        let optimization_result = opt_result.and_then(|s| serde_json::from_str(&s).ok());
        out.push(PlanAllocationAdjustFieldCultivationSnapshot::new(
            fc_id,
            field_id,
            crop_id,
            crop_name,
            variety,
            area,
            start_date,
            completion_date,
            cultivation_days,
            stage_count as i32,
            estimated_cost,
            optimization_result,
        ));
    }
    Ok(out)
}

fn load_plan_crop_rows(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<Vec<(i64, String, Option<String>)>> {
    let mut stmt = conn.prepare(
        "SELECT c.id, c.name, c.groups FROM cultivation_plan_crops cpc \
         INNER JOIN crops c ON c.id = cpc.crop_id \
         WHERE cpc.cultivation_plan_id = ?1 ORDER BY cpc.id",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok((
            row.get::<_, i64>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
        ))
    })?;

    rows.collect()
}

fn build_plan_crop_snapshots(
    pool: &SqlitePool,
    crop_rows: Vec<(i64, String, Option<String>)>,
) -> Result<
    Vec<agrr_domain::cultivation_plan::dtos::PlanAllocationAdjustPlanCropSnapshot>,
    Box<dyn std::error::Error + Send + Sync>,
> {
    let mut out = Vec::new();
    for (crop_id, crop_name, groups_raw) in crop_rows {
        let groups: Value = groups_raw
            .and_then(|g| serde_json::from_str(&g).ok())
            .unwrap_or_else(|| Value::Array(vec![]));
        let stage_count = crop_stage_count(pool, crop_id)?;
        let entry = match build_crop_agrr_requirement(pool, crop_id)? {
            Some(req_val) => PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
                crop_id,
                crop_name,
                groups,
                stage_count,
                Some(move || req_val),
            ),
            None => PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
                crop_id,
                crop_name,
                groups,
                stage_count,
                None::<fn() -> Value>,
            ),
        };
        out.push(entry);
    }
    Ok(out)
}

#[cfg(test)]
mod list_historical_weather_rows_tests {
    use super::*;
    use crate::weather_data::gcs_weather_test_support::{
        with_local_gcs_root, write_year_fixture, GcsBulkWeatherGateway,
    };
    use crate::weather_data::WeatherDataSqliteGateway;
    use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustReadGateway;
    use time::Month;

    fn temp_pool_with_weather_row() -> (SqlitePool, i64) {
        use std::sync::atomic::{AtomicU64, Ordering};
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!("agrr_adjust_read_weather_{n}.sqlite3"));
        let _ = std::fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_string_lossy());
        let location_id: i64 = pool
            .with_write(|conn| {
                conn.execute_batch(
                    "CREATE TABLE weather_locations (
                        id INTEGER PRIMARY KEY,
                        latitude REAL NOT NULL,
                        longitude REAL NOT NULL,
                        elevation REAL,
                        timezone TEXT
                    );
                    CREATE TABLE weather_data (
                        id INTEGER PRIMARY KEY,
                        weather_location_id INTEGER NOT NULL,
                        date TEXT NOT NULL,
                        temperature_max REAL,
                        temperature_min REAL,
                        temperature_mean REAL,
                        precipitation REAL,
                        sunshine_hours REAL,
                        wind_speed REAL,
                        weather_code INTEGER
                    );
                    INSERT INTO weather_locations (id, latitude, longitude, elevation, timezone)
                    VALUES (10, 35.0, 135.0, NULL, 'Asia/Tokyo');
                    INSERT INTO weather_data (weather_location_id, date, temperature_max, temperature_min, temperature_mean)
                    VALUES (10, '2024-06-01', 25.0, 15.0, 20.0);",
                )?;
                Ok(10_i64)
            })
            .expect("schema");
        (pool, location_id)
    }

    #[test]
    fn list_historical_weather_rows_reads_sqlite_when_active_record_gateway() {
        let (pool, location_id) = temp_pool_with_weather_row();
        let weather = Arc::new(WeatherDataSqliteGateway::new(pool.clone()));
        let metadata = Arc::new(crate::weather_data::PredictedWeatherMetadataSqliteGateway::new(
            pool.clone(),
        ));
        let gw = PlanAllocationAdjustReadSqliteGateway::new(pool, weather, metadata);
        let start = Date::from_calendar_date(2024, Month::June, 1).unwrap();
        let end = Date::from_calendar_date(2024, Month::June, 30).unwrap();
        let rows = gw
            .list_historical_weather_rows(Some(location_id), start, end)
            .expect("rows");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["date"], "2024-06-01");
    }

    #[test]
    fn list_historical_weather_rows_reads_gcs_bulk_without_sqlite_rows() {
        let (pool, location_id) = temp_pool_with_weather_row();
        with_local_gcs_root(|root| {
            std::env::set_var("WEATHER_DATA_STORAGE", "gcs");
            write_year_fixture(
                root,
                location_id,
                2024,
                r#"{"2024-06-01":{"temperature_max":22.0,"temperature_min":12.0}}"#,
            );
            let weather: Arc<dyn WeatherDataGateway> = Arc::new(
                GcsBulkWeatherGateway::from_local_env().expect("gcs gateway"),
            );
            let metadata = Arc::new(crate::weather_data::PredictedWeatherMetadataSqliteGateway::new(
                pool.clone(),
            ));
            let gw = PlanAllocationAdjustReadSqliteGateway::new(pool.clone(), weather, metadata);
            let start = Date::from_calendar_date(2024, Month::June, 1).unwrap();
            let end = Date::from_calendar_date(2024, Month::June, 30).unwrap();
            let rows = gw
                .list_historical_weather_rows(Some(location_id), start, end)
                .expect("rows");
            assert_eq!(rows.len(), 1);
            assert_eq!(rows[0]["temperature_max"], 22.0);
            std::env::remove_var("WEATHER_DATA_STORAGE");
        });
    }
}
