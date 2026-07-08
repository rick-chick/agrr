//! Ruby: `TaskScheduleGenerationReadActiveRecordGateway` — narrow read for task schedule generation.

use std::sync::Arc;

use crate::crop::agrr_requirement::build_crop_agrr_requirement;
use crate::cultivation_plan::planning_horizon::derive_planning_horizon;
use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::gateways::{
    TaskScheduleBlueprintRow, TaskScheduleCropRow, TaskScheduleFieldCultivationRow,
    TaskScheduleGenerationReadGateway, TaskSchedulePlanRow, TaskScheduleRelatedTask,
};
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use rusqlite::params;
use rust_decimal::Decimal;
use serde_json::{json, Value};
use time::{Date, OffsetDateTime};

pub struct TaskScheduleGenerationReadSqliteGateway {
    pool: SqlitePool,
    predicted_weather_store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl TaskScheduleGenerationReadSqliteGateway {
    pub fn new(
        pool: SqlitePool,
        predicted_weather_store: Arc<dyn PredictedWeatherStoreGateway>,
    ) -> Self {
        Self {
            pool,
            predicted_weather_store,
        }
    }
}

fn parse_date(s: &str) -> Option<Date> {
    let s = s.trim();
    if s.len() < 10 {
        return None;
    }
    Date::parse(&s[..10], &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
}

fn decimal_from_f64(v: Option<f64>) -> Option<Decimal> {
    v.and_then(Decimal::from_f64_retain)
}

fn map_related_task(
    id: Option<i64>,
    name: Option<String>,
    description: Option<String>,
    weather_dependency: Option<String>,
    time_per_sqm: Option<f64>,
) -> Option<TaskScheduleRelatedTask> {
    let id = id?;
    let name = name.filter(|n| !n.trim().is_empty())?;
    Some(TaskScheduleRelatedTask {
        id,
        name,
        description,
        weather_dependency,
        time_per_sqm: decimal_from_f64(time_per_sqm),
    })
}

impl TaskScheduleGenerationReadGateway for TaskScheduleGenerationReadSqliteGateway {
    fn find_plan_row(
        &self,
        plan_id: i64,
    ) -> Result<TaskSchedulePlanRow, Box<dyn std::error::Error + Send + Sync>> {
        let header = self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT cp.id, cp.plan_type, cp.plan_year, cp.planning_start_date, cp.planning_end_date, \
                 (SELECT MIN(fc.start_date) FROM field_cultivations fc WHERE fc.cultivation_plan_id = cp.id), \
                 (SELECT MAX(fc.completion_date) FROM field_cultivations fc WHERE fc.cultivation_plan_id = cp.id) \
                 FROM cultivation_plans cp WHERE cp.id = ?1 LIMIT 1",
                params![plan_id],
                |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, Option<i32>>(2)?,
                        row.get::<_, Option<String>>(3)?,
                        row.get::<_, Option<String>>(4)?,
                        row.get::<_, Option<String>>(5)?,
                        row.get::<_, Option<String>>(6)?,
                    ))
                },
            )
        })?;

        let predicted_weather_data = self
            .predicted_weather_store
            .read_payload(PredictedWeatherScope::Plan, plan_id)?
            .unwrap_or_else(|| json!({}));

        let today = OffsetDateTime::now_utc().date();
        let (
            id,
            plan_type,
            plan_year,
            planning_start,
            planning_end,
            fc_min_start,
            fc_max_completion,
        ) = header;
        let horizon = derive_planning_horizon(
            &plan_type,
            plan_year,
            planning_start.as_deref(),
            planning_end.as_deref(),
            fc_min_start.as_deref(),
            fc_max_completion.as_deref(),
            today,
        );

        Ok(TaskSchedulePlanRow {
            id,
            predicted_weather_data,
            calculated_planning_start_date: horizon.calculated_planning_start_date,
        })
    }

    fn list_field_cultivation_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<TaskScheduleFieldCultivationRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT fc.id, fc.start_date, cpc.crop_id \
                 FROM field_cultivations fc \
                 INNER JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
                 WHERE fc.cultivation_plan_id = ?1 \
                 ORDER BY fc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let start_raw: Option<String> = row.get(1)?;
                Ok(TaskScheduleFieldCultivationRow {
                    id: row.get(0)?,
                    start_date: start_raw.as_deref().and_then(parse_date),
                    crop_id: row.get(2)?,
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
        })
    }

    fn find_crop_row(
        &self,
        crop_id: i64,
    ) -> Result<TaskScheduleCropRow, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name FROM crops WHERE id = ?1",
                params![crop_id],
                |row| {
                    Ok(TaskScheduleCropRow {
                        id: row.get(0)?,
                        name: row.get(1)?,
                    })
                },
            )
        })
    }

    fn list_crop_task_schedule_blueprint_rows(
        &self,
        crop_id: i64,
    ) -> Result<Vec<TaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT b.id, b.task_type, b.gdd_trigger, b.gdd_tolerance, b.description, \
                 b.stage_name, b.stage_order, b.priority, b.source, b.weather_dependency, \
                 b.time_per_sqm, b.amount, b.amount_unit, \
                 at.id, at.name, at.description, at.weather_dependency, at.time_per_sqm \
                 FROM crop_task_schedule_blueprints b \
                 LEFT JOIN agricultural_tasks at ON at.id = b.agricultural_task_id \
                 WHERE b.crop_id = ?1 \
                 ORDER BY b.stage_order, b.id",
            )?;
            let rows = stmt.query_map(params![crop_id], |row| {
                Ok(TaskScheduleBlueprintRow {
                    id: row.get(0)?,
                    task_type: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
                    gdd_trigger: decimal_from_f64(row.get(2)?),
                    gdd_tolerance: decimal_from_f64(row.get(3)?),
                    description: row.get(4)?,
                    stage_name: row.get(5)?,
                    stage_order: row.get(6)?,
                    priority: row.get(7)?,
                    source: row.get(8)?,
                    weather_dependency: row.get(9)?,
                    time_per_sqm: decimal_from_f64(row.get(10)?),
                    amount: decimal_from_f64(row.get(11)?),
                    amount_unit: row.get(12)?,
                    agricultural_task: map_related_task(
                        row.get(13)?,
                        row.get(14)?,
                        row.get(15)?,
                        row.get(16)?,
                        row.get(17)?,
                    ),
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
        })
    }

    fn build_crop_agrr_requirement(
        &self,
        crop_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        build_crop_agrr_requirement(&self.pool, crop_id)?
            .ok_or_else(|| format!("crop #{crop_id} has no agrr requirement").into())
    }
}
