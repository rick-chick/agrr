//! Plan copy steps for public plan save (Ruby `PlanCopyActiveRecordGateway` with `PlanSaveContext`).

use std::collections::HashMap;

use crate::pool::SqlitePool;
use crate::weather_data::PredictedWeatherGatewayBundle;
use agrr_domain::cultivation_plan::calculators::planning_date_calculator::{
    calculate_plan_year_from_cultivations, calculate_planning_dates_for_year,
    calculate_planning_dates_from_cultivations, CultivationPeriod,
};
use super::plan_save_support::{OptionalRow, PlanSaveNoopLogger};

const INVALID_TASK_SCHEDULE_MARKER: &str = "InvalidTaskScheduleItem";
use agrr_domain::cultivation_plan::dtos::PublicPlanSaveSessionData;
use agrr_domain::shared::exceptions::InvalidTaskScheduleItemError;
use agrr_domain::shared::ports::ClockPort;
use rusqlite::params;

use super::plan_save_gateways::{resolve_agricultural_task_id, PlanSaveUserAgriculturalTaskGw};

pub(crate) struct PlanSaveContext {
    pub user_id: i64,
    pub session_data: PublicPlanSaveSessionData,
    pub ref_cpc_id_to_user_crop_id: HashMap<i64, i64>,
    pub reference_agricultural_task_id_to_user_task_id: HashMap<i64, i64>,
}

pub(crate) struct PlanSavePlanCopy<'a> {
    pool: SqlitePool,
    ctx: &'a mut PlanSaveContext,
    clock: &'a dyn ClockPort,
}

impl<'a> PlanSavePlanCopy<'a> {
    pub fn new(pool: SqlitePool, ctx: &'a mut PlanSaveContext, clock: &'a dyn ClockPort) -> Self {
        Self { pool, ctx, clock }
    }

    fn ag_task_gateway(&self) -> PlanSaveUserAgriculturalTaskGw {
        PlanSaveUserAgriculturalTaskGw::new(self.pool.clone())
    }

    pub fn copy_cultivation_plan(
        &self,
        farm_id: i64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let plan_id = self.ctx.session_data.plan_id;
        let new_plan_id = self.pool.with_write_box(|conn| {
            let (total_area, plan_year, reference_farm_name): (f64, Option<i32>, Option<String>) =
                conn.query_row(
                    "SELECT cp.total_area, cp.plan_year, f.name \
                     FROM cultivation_plans cp \
                     INNER JOIN farms f ON f.id = cp.farm_id \
                     WHERE cp.id = ?1",
                    params![plan_id],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )?;

            let mut periods: Vec<CultivationPeriod> = Vec::new();
            let mut stmt = conn.prepare(
                "SELECT start_date, completion_date FROM field_cultivations \
                 WHERE cultivation_plan_id = ?1 AND start_date IS NOT NULL AND completion_date IS NOT NULL",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let start: String = row.get(0)?;
                let end: String = row.get(1)?;
                Ok((start, end))
            })?;
            for row in rows {
                let (start, end) = row?;
                if let (Some(s), Some(e)) = (parse_date_str(&start), parse_date_str(&end)) {
                    periods.push(CultivationPeriod {
                        start_date: s,
                        completion_date: e,
                    });
                }
            }

            let logger = PlanSaveNoopLogger;
            let as_of = self.clock.today();
            let (plan_year_val, planning_start, planning_end) = if plan_year.is_none() {
                let range =
                    calculate_planning_dates_from_cultivations(&periods, &logger, as_of);
                (
                    None,
                    range.start_date.to_string(),
                    range.end_date.to_string(),
                )
            } else {
                let year = calculate_plan_year_from_cultivations(&periods, &logger, as_of);
                let range = calculate_planning_dates_for_year(year);
                (
                    Some(year),
                    range.start_date.to_string(),
                    range.end_date.to_string(),
                )
            };

            let plan_name = format!(
                "{}の計画",
                reference_farm_name.as_deref().unwrap_or("")
            );

            conn.execute(
                "INSERT INTO cultivation_plans (farm_id, user_id, total_area, plan_type, plan_year, plan_name, \
                 planning_start_date, planning_end_date, status, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, 'private', ?4, ?5, ?6, ?7, 'pending', datetime('now'), datetime('now'))",
                params![
                    farm_id,
                    self.ctx.user_id,
                    total_area,
                    plan_year_val,
                    plan_name,
                    planning_start,
                    planning_end,
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })?;

        let predicted = PredictedWeatherGatewayBundle::resolve(self.pool.clone())?;
        predicted
            .metadata
            .copy_plan_metadata(plan_id, new_plan_id)?;
        predicted.store.copy_plan_payload(plan_id, new_plan_id)?;
        Ok(new_plan_id)
    }

    pub fn establish_master_data_relationships(&self) {}

    pub fn copy_plan_relations(
        &self,
        new_plan_id: i64,
    ) -> Result<HashMap<i64, i64>, Box<dyn std::error::Error + Send + Sync>> {
        let plan_id = self.ctx.session_data.plan_id;
        self.pool.with_write_box(|conn| {
            let mut field_map: HashMap<i64, i64> = HashMap::new();
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, description FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1",
            )?;
            let fields = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, f64>(2)?,
                    row.get::<_, f64>(3)?,
                    row.get::<_, Option<String>>(4)?,
                ))
            })?;
            let mut new_fields: Vec<(i64, String)> = Vec::new();
            for field in fields {
                let (old_id, name, area, daily_fixed_cost, description) = field?;
                conn.execute(
                    "INSERT INTO cultivation_plan_fields (cultivation_plan_id, name, area, daily_fixed_cost, description, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'), datetime('now'))",
                    params![new_plan_id, name, area, daily_fixed_cost, description],
                )?;
                let new_id = conn.last_insert_rowid();
                field_map.insert(old_id, new_id);
                new_fields.push((new_id, name));
            }

            let mut new_crops: Vec<(i64, i64)> = Vec::new();
            let mut stmt = conn.prepare(
                "SELECT id, crop_id, name, variety, area_per_unit, revenue_per_area FROM cultivation_plan_crops WHERE cultivation_plan_id = ?1 ORDER BY id",
            )?;
            let cpcs = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, Option<String>>(3)?,
                    row.get::<_, f64>(4)?,
                    row.get::<_, f64>(5)?,
                ))
            })?;
            for cpc in cpcs {
                let (old_cpc_id, _ref_crop, name, variety, area_per_unit, revenue_per_area) = cpc?;
                let Some(user_crop_id) = self.ctx.ref_cpc_id_to_user_crop_id.get(&old_cpc_id) else {
                    continue;
                };
                conn.execute(
                    "INSERT INTO cultivation_plan_crops (cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))",
                    params![
                        new_plan_id,
                        user_crop_id,
                        name,
                        variety,
                        area_per_unit,
                        revenue_per_area
                    ],
                )?;
                new_crops.push((conn.last_insert_rowid(), *user_crop_id));
            }

            let mut fc_map: HashMap<i64, i64> = HashMap::new();
            let mut stmt = conn.prepare(
                "SELECT fc.id, cpf.name, fc.cultivation_plan_crop_id, fc.area, fc.start_date, fc.completion_date, \
                 fc.cultivation_days, fc.estimated_cost, fc.status, fc.optimization_result \
                 FROM field_cultivations fc \
                 INNER JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
                 WHERE fc.cultivation_plan_id = ?1",
            )?;
            let fcs = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, f64>(3)?,
                    row.get::<_, Option<String>>(4)?,
                    row.get::<_, Option<String>>(5)?,
                    row.get::<_, Option<i64>>(6)?,
                    row.get::<_, Option<f64>>(7)?,
                    row.get::<_, String>(8)?,
                    row.get::<_, Option<String>>(9)?,
                ))
            })?;
            for fc in fcs {
                let (
                    old_fc_id,
                    field_name,
                    old_cpc_id,
                    area,
                    start_date,
                    completion_date,
                    cultivation_days,
                    estimated_cost,
                    status,
                    optimization_result,
                ) = fc?;
                let new_field_id = new_fields
                    .iter()
                    .find(|(_, n)| *n == field_name)
                    .map(|(id, _)| *id);
                let user_crop_id = self
                    .ctx
                    .ref_cpc_id_to_user_crop_id
                    .get(&old_cpc_id)
                    .copied();
                let new_cpc_id = user_crop_id.and_then(|uid| {
                    new_crops
                        .iter()
                        .find(|(_, crop_id)| *crop_id == uid)
                        .map(|(id, _)| *id)
                });
                let (Some(new_field_id), Some(new_cpc_id)) = (new_field_id, new_cpc_id) else {
                    continue;
                };
                conn.execute(
                    "INSERT INTO field_cultivations (cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, \
                     area, start_date, completion_date, cultivation_days, estimated_cost, status, optimization_result, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, datetime('now'), datetime('now'))",
                    params![
                        new_plan_id,
                        new_field_id,
                        new_cpc_id,
                        area,
                        start_date,
                        completion_date,
                        cultivation_days,
                        estimated_cost,
                        status,
                        optimization_result,
                    ],
                )?;
                fc_map.insert(old_fc_id, conn.last_insert_rowid());
            }
            Ok(fc_map)
        })
    }

    pub fn copy_task_schedules(
        &mut self,
        new_plan_id: i64,
        field_cultivation_map: &HashMap<i64, i64>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if field_cultivation_map.is_empty() {
            return Ok(());
        }
        let plan_id = self.ctx.session_data.plan_id;
        let ag_gw = self.ag_task_gateway();
        let user_id = self.ctx.user_id;
        let mut task_map = self
            .ctx
            .reference_agricultural_task_id_to_user_task_id
            .clone();
        let result = self.pool.with_write(|conn| {
            let invalid: Option<i64> = conn
                .query_row(
                    "SELECT tsi.id FROM task_schedule_items tsi \
                     INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
                     WHERE ts.cultivation_plan_id = ?1 AND tsi.gdd_trigger IS NULL LIMIT 1",
                    params![plan_id],
                    |r| r.get(0),
                )
                .optional()?;
            if invalid.is_some() {
                return Err(rusqlite::Error::InvalidParameterName(
                    INVALID_TASK_SCHEDULE_MARKER.into(),
                ));
            }

            let mut stmt = conn.prepare(
                "SELECT ts.id, ts.field_cultivation_id, ts.category, ts.status, ts.generated_at \
                 FROM task_schedules ts WHERE ts.cultivation_plan_id = ?1",
            )?;
            let schedules = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, Option<String>>(3)?,
                    row.get::<_, Option<String>>(4)?,
                ))
            })?;

            for schedule in schedules {
                let (sched_id, old_fc_id, category, status, generated_at) = schedule?;
                let Some(new_fc_id) = field_cultivation_map.get(&old_fc_id) else {
                    continue;
                };
                conn.execute(
                    "INSERT INTO task_schedules (cultivation_plan_id, field_cultivation_id, category, status, source, generated_at, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, 'copied_from_public_plan', ?5, datetime('now'), datetime('now'))",
                    params![
                        new_plan_id,
                        new_fc_id,
                        category,
                        status.unwrap_or_else(|| "active".to_string()),
                        generated_at,
                    ],
                )?;
                let new_schedule_id = conn.last_insert_rowid();

                let mut item_stmt = conn.prepare(
                    "SELECT task_type, name, stage_name, stage_order, gdd_trigger, gdd_tolerance, scheduled_date, \
                     priority, source, weather_dependency, time_per_sqm, amount, amount_unit, status, actual_date, \
                     actual_notes, rescheduled_at, cancelled_at, completed_at, agricultural_task_id, source_agricultural_task_id \
                     FROM task_schedule_items WHERE task_schedule_id = ?1",
                )?;
                let items = item_stmt.query_map(params![sched_id], |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, Option<String>>(2)?,
                        row.get::<_, Option<i32>>(3)?,
                        row.get::<_, Option<f64>>(4)?,
                        row.get::<_, Option<f64>>(5)?,
                        row.get::<_, Option<String>>(6)?,
                        row.get::<_, Option<i32>>(7)?,
                        row.get::<_, Option<String>>(8)?,
                        row.get::<_, Option<String>>(9)?,
                        row.get::<_, Option<f64>>(10)?,
                        row.get::<_, Option<f64>>(11)?,
                        row.get::<_, Option<String>>(12)?,
                        row.get::<_, Option<String>>(13)?,
                        row.get::<_, Option<String>>(14)?,
                        row.get::<_, Option<String>>(15)?,
                        row.get::<_, Option<String>>(16)?,
                        row.get::<_, Option<String>>(17)?,
                        row.get::<_, Option<String>>(18)?,
                        row.get::<_, Option<i64>>(19)?,
                        row.get::<_, Option<i64>>(20)?,
                    ))
                })?;
                for item in items {
                    let (
                        task_type,
                        name,
                        stage_name,
                        stage_order,
                        gdd_trigger,
                        gdd_tolerance,
                        scheduled_date,
                        priority,
                        source,
                        weather_dependency,
                        time_per_sqm,
                        amount,
                        amount_unit,
                        status,
                        actual_date,
                        actual_notes,
                        rescheduled_at,
                        cancelled_at,
                        completed_at,
                        agricultural_task_id,
                        source_agricultural_task_id,
                    ) = item?;
                    if gdd_trigger.is_none() {
                        return Err(rusqlite::Error::InvalidParameterName(
                            INVALID_TASK_SCHEDULE_MARKER.into(),
                        ));
                    }
                    let ref_task = source_agricultural_task_id.or(agricultural_task_id);
                    let mapped_task = ref_task
                        .and_then(|id| {
                            resolve_agricultural_task_id(id, user_id, &mut task_map, &ag_gw)
                                .ok()
                                .flatten()
                        })
                        .or(agricultural_task_id);
                    conn.execute(
                        "INSERT INTO task_schedule_items (task_schedule_id, task_type, name, stage_name, stage_order, \
                         gdd_trigger, gdd_tolerance, scheduled_date, priority, source, weather_dependency, time_per_sqm, \
                         amount, amount_unit, status, actual_date, actual_notes, rescheduled_at, cancelled_at, completed_at, \
                         agricultural_task_id, source_agricultural_task_id, created_at, updated_at) \
                         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, datetime('now'), datetime('now'))",
                        params![
                            new_schedule_id,
                            task_type,
                            name,
                            stage_name,
                            stage_order,
                            gdd_trigger,
                            gdd_tolerance,
                            scheduled_date,
                            priority,
                            source,
                            weather_dependency,
                            time_per_sqm,
                            amount,
                            amount_unit,
                            status.unwrap_or_else(|| "planned".to_string()),
                            actual_date,
                            actual_notes,
                            rescheduled_at,
                            cancelled_at,
                            completed_at,
                            mapped_task,
                            source_agricultural_task_id,
                        ],
                    )?;
                }
            }
            Ok(())
        });
        self.ctx.reference_agricultural_task_id_to_user_task_id = task_map;
        match result {
            Ok(()) => Ok(()),
            Err(rusqlite::Error::InvalidParameterName(s)) if s == INVALID_TASK_SCHEDULE_MARKER => {
                Err(Box::new(InvalidTaskScheduleItemError))
            }
            Err(e) => Err(Box::new(e)),
        }
    }
}

fn parse_date_str(s: &str) -> Option<time::Date> {
    let s = s.trim();
    if s.len() < 10 {
        return None;
    }
    let y: i32 = s.get(0..4)?.parse().ok()?;
    let m: u8 = s.get(5..7)?.parse().ok()?;
    let d: u8 = s.get(8..10)?.parse().ok()?;
    time::Date::from_calendar_date(y, time::Month::try_from(m).ok()?, d).ok()
}
