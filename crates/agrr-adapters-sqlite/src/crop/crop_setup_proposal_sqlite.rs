//! Atomic apply for crop setup proposals.

use crate::crop::crop_task_schedule_blueprint_sqlite::{insert_blueprint_on_conn, map_blueprint_entity};
use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::entities::AgriculturalTaskEntity;
use agrr_domain::crop::dtos::{
    CropSetupProposalApplyResult, CropSetupProposalAgriculturalTaskPlan, CropSetupProposalPlan,
    CropSetupProposalStagePlan, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateInput,
};
use agrr_domain::crop::gateways::CropSetupProposalGateway;
use agrr_domain::crop::policies::{
    masters_crop_task_schedule_blueprint_create_policy,
    masters_crop_task_schedule_blueprint_duplicate_policy,
};
use agrr_domain::shared::exceptions::RecordInvalidError;
use rusqlite::{params, Connection, Error as SqliteError};
use serde_json::{Map, Value};
use std::collections::HashMap;

pub struct CropSetupProposalSqliteGateway {
    pool: SqlitePool,
}

impl CropSetupProposalSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropSetupProposalGateway for CropSetupProposalSqliteGateway {
    fn apply_plan(
        &self,
        user_id: i64,
        crop_id: i64,
        plan: &CropSetupProposalPlan,
    ) -> Result<CropSetupProposalApplyResult, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_write_transaction_box(|conn| apply_plan_on_conn(conn, user_id, crop_id, plan))
    }
}

fn apply_plan_on_conn(
    conn: &Connection,
    user_id: i64,
    crop_id: i64,
    plan: &CropSetupProposalPlan,
) -> rusqlite::Result<CropSetupProposalApplyResult> {
    let mut task_ref_to_id = HashMap::new();
    let mut agricultural_task_ids = Vec::new();

    for task in &plan.agricultural_tasks {
        let task_id = find_or_create_agricultural_task(conn, user_id, task)?;
        task_ref_to_id.insert(task.ref_key.clone(), task_id);
        agricultural_task_ids.push(task_id);
    }

    let mut stage_ids = Vec::new();
    for stage in &plan.stages {
        let stage_id = create_stage_with_requirements(conn, crop_id, stage)?;
        stage_ids.push(stage_id);
    }

    let existing_blueprints = list_blueprints_on_conn(conn, crop_id)?;
    let mut created_blueprints = existing_blueprints;
    let mut blueprint_ids = Vec::new();

    for blueprint in &plan.task_schedule_blueprints {
        let agricultural_task_id = *task_ref_to_id.get(&blueprint.agricultural_task_ref).ok_or_else(
            || invalid_apply_error("agricultural task ref missing"),
        )?;

        if masters_crop_task_schedule_blueprint_duplicate_policy::conflicts_with_existing(
            &created_blueprints,
            None,
            agricultural_task_id,
            Some(blueprint.stage_order),
            Some(blueprint.gdd_trigger),
        ) {
            return Err(invalid_apply_error("duplicate blueprint"));
        }

        let agricultural_task = load_agricultural_task(conn, agricultural_task_id)?;
        let persist_attrs = masters_crop_task_schedule_blueprint_create_policy::build_persist_attributes(
            &MastersCropTaskScheduleBlueprintCreateInput {
                user_id,
                crop_id,
                agricultural_task_id: Some(agricultural_task_id),
                stage_order: Some(blueprint.stage_order),
                stage_name: blueprint.stage_name.clone(),
                gdd_trigger: Some(blueprint.gdd_trigger),
                task_type: Some(blueprint.task_type.clone()),
                priority: Some(blueprint.priority),
                description: None,
            },
            agricultural_task_id,
            Some(blueprint.stage_order),
            Some(blueprint.gdd_trigger),
            &agricultural_task,
        );

        let row = insert_blueprint_on_conn(conn, &persist_attrs)
            .map_err(|err| SqliteError::ToSqlConversionFailure(err))?;
        blueprint_ids.push(row.id);
        created_blueprints.push(row);
    }

    Ok(CropSetupProposalApplyResult {
        stage_ids,
        agricultural_task_ids,
        blueprint_ids,
    })
}

fn find_or_create_agricultural_task(
    conn: &Connection,
    user_id: i64,
    task: &CropSetupProposalAgriculturalTaskPlan,
) -> rusqlite::Result<i64> {
    if let Some(id) = conn
        .query_row(
            "SELECT id FROM agricultural_tasks WHERE user_id = ?1 AND name = ?2 AND is_reference = 0",
            params![user_id, task.name],
            |row| row.get::<_, i64>(0),
        )
        .ok()
    {
        return Ok(id);
    }

    conn.execute(
        "INSERT INTO agricultural_tasks (name, description, time_per_sqm, weather_dependency, required_tools, skill_level, is_reference, user_id, region, task_type, created_at, updated_at) \
         VALUES (?1, ?2, ?3, NULL, '[]', ?4, 0, ?5, ?6, ?7, datetime('now'), datetime('now'))",
        params![
            task.name,
            task.description,
            task.time_per_sqm,
            task.skill_level,
            user_id,
            task.region,
            task.task_type,
        ],
    )?;
    Ok(conn.last_insert_rowid())
}

fn load_agricultural_task(conn: &Connection, id: i64) -> rusqlite::Result<AgriculturalTaskEntity> {
    conn.query_row(
        "SELECT id, user_id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, region, task_type, is_reference, created_at, updated_at \
         FROM agricultural_tasks WHERE id = ?1",
        params![id],
        |row| {
            let is_reference: i64 = row.get(10)?;
            Ok(AgriculturalTaskEntity {
                id: Some(row.get(0)?),
                user_id: row.get(1)?,
                name: row.get(2)?,
                description: row.get(3)?,
                time_per_sqm: row.get(4)?,
                weather_dependency: row.get(5)?,
                required_tools: vec![],
                skill_level: row.get(7)?,
                region: row.get(8)?,
                task_type: row.get(9)?,
                is_reference: is_reference != 0,
                created_at: row.get(11)?,
                updated_at: row.get(12)?,
            })
        },
    )
}

fn create_stage_with_requirements(
    conn: &Connection,
    crop_id: i64,
    stage: &CropSetupProposalStagePlan,
) -> rusqlite::Result<i64> {
    conn.execute(
        "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at) VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
        params![crop_id, stage.name, stage.order],
    )?;
    let stage_id = conn.last_insert_rowid();

    insert_thermal_requirement(conn, stage_id, &stage.thermal_requirement)?;

    if let Some(temperature) = stage.temperature_requirement.as_ref() {
        insert_temperature_requirement(conn, stage_id, temperature)?;
    }
    if let Some(sunshine) = stage.sunshine_requirement.as_ref() {
        insert_sunshine_requirement(conn, stage_id, sunshine)?;
    }
    if let Some(nutrient) = stage.nutrient_requirement.as_ref() {
        insert_nutrient_requirement(conn, stage_id, nutrient)?;
    }

    Ok(stage_id)
}

fn insert_thermal_requirement(
    conn: &Connection,
    crop_stage_id: i64,
    payload: &Value,
) -> rusqlite::Result<()> {
    let gdd = parse_required_gdd(payload).unwrap_or(0.0);
    conn.execute(
        "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at) VALUES (?1, ?2, datetime('now'), datetime('now'))",
        params![crop_stage_id, gdd],
    )?;
    Ok(())
}

fn insert_temperature_requirement(
    conn: &Connection,
    crop_stage_id: i64,
    payload: &Value,
) -> rusqlite::Result<()> {
    let empty = Map::new();
    let m = payload.as_object().unwrap_or(&empty);
    conn.execute(
        "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature, created_at, updated_at) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now'))",
        params![
            crop_stage_id,
            parse_f64_field(m, "base_temperature"),
            parse_f64_field(m, "optimal_min"),
            parse_f64_field(m, "optimal_max"),
            parse_f64_field(m, "low_stress_threshold"),
            parse_f64_field(m, "high_stress_threshold"),
            parse_f64_field(m, "frost_threshold"),
            parse_f64_field(m, "sterility_risk_threshold"),
            parse_f64_field(m, "max_temperature"),
        ],
    )?;
    Ok(())
}

fn insert_sunshine_requirement(
    conn: &Connection,
    crop_stage_id: i64,
    payload: &Value,
) -> rusqlite::Result<()> {
    let empty = Map::new();
    let m = payload.as_object().unwrap_or(&empty);
    conn.execute(
        "INSERT INTO sunshine_requirements (crop_stage_id, minimum_sunshine_hours, target_sunshine_hours, created_at, updated_at) \
         VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
        params![
            crop_stage_id,
            parse_f64_field(m, "minimum_sunshine_hours"),
            parse_f64_field(m, "target_sunshine_hours"),
        ],
    )?;
    Ok(())
}

fn insert_nutrient_requirement(
    conn: &Connection,
    crop_stage_id: i64,
    payload: &Value,
) -> rusqlite::Result<()> {
    let empty = Map::new();
    let m = payload.as_object().unwrap_or(&empty);
    conn.execute(
        "INSERT INTO nutrient_requirements (crop_stage_id, daily_uptake_n, daily_uptake_p, daily_uptake_k, region, created_at, updated_at) \
         VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'), datetime('now'))",
        params![
            crop_stage_id,
            parse_f64_field(m, "daily_uptake_n"),
            parse_f64_field(m, "daily_uptake_p"),
            parse_f64_field(m, "daily_uptake_k"),
            parse_str_field(m, "region"),
        ],
    )?;
    Ok(())
}

fn list_blueprints_on_conn(
    conn: &Connection,
    crop_id: i64,
) -> rusqlite::Result<Vec<MastersCropTaskScheduleBlueprint>> {
    let sql = "SELECT id, crop_id, agricultural_task_id, source_agricultural_task_id, \
        stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, amount, \
        amount_unit, description, time_per_sqm, weather_dependency, name, created_at, updated_at \
        FROM crop_task_schedule_blueprints WHERE crop_id = ?1 ORDER BY COALESCE(stage_order, 999999), id";
    let mut stmt = conn.prepare(sql)?;
    let rows = stmt.query_map(params![crop_id], map_blueprint_entity)?;
    rows.collect::<Result<Vec<_>, _>>()
}

fn invalid_apply_error(message: &str) -> SqliteError {
    SqliteError::ToSqlConversionFailure(Box::new(RecordInvalidError::new(
        Some(message.into()),
        None,
    )))
}

fn parse_required_gdd(value: &Value) -> Option<f64> {
    value
        .get("required_gdd")
        .and_then(parse_f64)
        .filter(|v| v.is_finite())
}

fn parse_f64(value: &Value) -> Option<f64> {
    value
        .as_f64()
        .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
}

fn parse_f64_field(m: &Map<String, Value>, key: &str) -> Option<f64> {
    m.get(key).and_then(parse_f64)
}

fn parse_str_field(m: &Map<String, Value>, key: &str) -> Option<String> {
    m.get(key).and_then(|v| v.as_str()).map(str::to_string)
}
