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
use agrr_domain::weather_data::dtos::{CultivationPlanWeather, WeatherLocation};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use std::collections::HashMap;
use time::Date;

pub struct PlanAllocationAdjustReadSqliteGateway {
    pool: SqlitePool,
}

impl PlanAllocationAdjustReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
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

fn parse_json_opt(raw: Option<String>) -> Option<Value> {
    raw.and_then(|s| serde_json::from_str(&s).ok())
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
                     cp.predicted_weather_data, \
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
                            row.get::<_, Option<String>>(5)?,
                            row.get::<_, Option<i64>>(6)?,
                            row.get::<_, Option<String>>(7)?,
                            row.get::<_, Option<f64>>(8)?,
                            row.get::<_, Option<f64>>(9)?,
                            row.get::<_, Option<i64>>(10)?,
                            row.get::<_, Option<f64>>(11)?,
                            row.get::<_, Option<f64>>(12)?,
                            row.get::<_, Option<f64>>(13)?,
                            row.get::<_, Option<String>>(14)?,
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
                predicted_weather_data,
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
        let predicted_json = parse_json_opt(predicted_weather_data);

        let weather_location = match (wl_id, wl_lat, wl_lon) {
                (Some(id), Some(lat), Some(lon)) => {
                    let wl = WeatherLocation::new(
                        id,
                        lat,
                        lon,
                        wl_elevation,
                        wl_timezone,
                        None,
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
                predicted_json,
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
        let start = historical_start.to_string();
        let end = historical_end.to_string();
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT date, temperature_max, temperature_min, temperature_mean, \
                 precipitation, sunshine_hours, wind_speed, weather_code \
                 FROM weather_data \
                 WHERE weather_location_id = ?1 AND date >= ?2 AND date <= ?3 \
                 AND temperature_max IS NOT NULL AND temperature_min IS NOT NULL \
                 ORDER BY date",
            )?;
            let rows = stmt.query_map(
                params![weather_location_id, start, end],
                |row| {
                    Ok(json!({
                        "date": row.get::<_, String>(0)?,
                        "temperature_max": row.get::<_, f64>(1)?,
                        "temperature_min": row.get::<_, f64>(2)?,
                        "temperature_mean": row.get::<_, Option<f64>>(3)?,
                        "precipitation": row.get::<_, Option<f64>>(4)?,
                        "sunshine_hours": row.get::<_, Option<f64>>(5)?,
                        "wind_speed": row.get::<_, Option<f64>>(6)?,
                        "weather_code": row.get::<_, Option<i64>>(7)?,
                    }))
                },
            )?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
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
