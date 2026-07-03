//! Soft-delete scheduling compatible with Rails `DeletionUndoEvent` / `SnapshotRestorer`.

use crate::pool::SqlitePool;
use agrr_domain::shared::exceptions::AssociationInUseError;
use rusqlite::{params, Connection, Row};
use serde_json::{json, Map, Value};
use std::collections::BTreeMap;
use time::{format_description::well_known::Iso8601, OffsetDateTime};

const DEFAULT_TTL_SECS: i64 = 300;

#[derive(Debug, Clone)]
pub struct ScheduledUndo {
    pub undo_token: String,
    pub expires_at: String,
    pub metadata: Value,
}

pub fn schedule_destroy(
    pool: &SqlitePool,
    resource_type: &str,
    resource_id: i64,
    actor_id: i64,
    toast_message: &str,
    auto_hide_after: i64,
    extra_metadata: BTreeMap<String, Value>,
) -> Result<ScheduledUndo, Box<dyn std::error::Error + Send + Sync>> {
    pool.with_write_box(|conn| {
        let snapshot = build_snapshot(conn, resource_type, resource_id)?;
        let undo_token = new_uuid_v4();
        let expires_at = OffsetDateTime::now_utc() + time::Duration::seconds(default_ttl_secs());
        let expires_at_str = expires_at
            .format(&Iso8601::DEFAULT)
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;
        let now = OffsetDateTime::now_utc()
            .format(&Iso8601::DEFAULT)
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;

        let mut metadata = Map::new();
        metadata.insert("toast_message".into(), json!(toast_message));
        metadata.insert(
            "resource_label".into(),
            json!(resource_label(conn, resource_type, resource_id)?),
        );
        metadata.insert("auto_hide_after".into(), json!(auto_hide_after));
        metadata.insert("undo_deadline".into(), json!(expires_at_str.clone()));
        metadata.insert(
            "resource_dom_id".into(),
            json!(resource_dom_id(resource_type, resource_id)),
        );
        for (k, v) in extra_metadata {
            metadata.insert(k, v);
        }
        let metadata_json = Value::Object(metadata.clone());

        conn.execute(
            "INSERT INTO deletion_undo_events \
             (id, resource_type, resource_id, snapshot, metadata, deleted_by_id, expires_at, state, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'scheduled', ?8, ?8)",
            params![
                undo_token,
                resource_type,
                resource_id.to_string(),
                serde_json::to_string(&snapshot)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
                serde_json::to_string(&metadata_json)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
                actor_id,
                expires_at_str,
                now,
            ],
        )?;

        match resource_type {
            "Farm" => {
                conn.execute("DELETE FROM fields WHERE farm_id = ?1", params![resource_id])?;
                let deleted = conn.execute("DELETE FROM farms WHERE id = ?1", params![resource_id])?;
                if deleted == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }
            "Crop" => {
                if crop_has_restricted_usage(conn, resource_id)? {
                    return Err(rusqlite::Error::SqliteFailure(
                        rusqlite::ffi::Error::new(19),
                        Some("association in use".into()),
                    ));
                }
                delete_crop_graph(conn, resource_id)?;
            }
            "Field" => {
                let deleted =
                    conn.execute("DELETE FROM fields WHERE id = ?1", params![resource_id])?;
                if deleted == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }
            "CultivationPlan" => {
                delete_cultivation_plan_graph(conn, resource_id)?;
            }
            "Pest" | "Fertilize" | "Pesticide" | "AgriculturalTask" | "InteractionRule" => {
                let table = master_table_name(resource_type)?;
                let sql = format!("DELETE FROM {table} WHERE id = ?1");
                let deleted = conn.execute(&sql, params![resource_id])?;
                if deleted == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }
            "WorkRecord" => {
                let deleted =
                    conn.execute("DELETE FROM work_records WHERE id = ?1", params![resource_id])?;
                if deleted == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }
            _ => {
                return Err(rusqlite::Error::InvalidParameterName(
                    resource_type.into(),
                ));
            }
        }

        Ok(ScheduledUndo {
            undo_token,
            expires_at: expires_at_str,
            metadata: Value::Object(metadata),
        })
    })
    .map_err(map_schedule_error)
}

fn map_schedule_error(
    err: Box<dyn std::error::Error + Send + Sync>,
) -> Box<dyn std::error::Error + Send + Sync> {
    if let Some(sqlite) = err.downcast_ref::<rusqlite::Error>() {
        if let rusqlite::Error::SqliteFailure(code, Some(msg)) = sqlite {
            if code.code == rusqlite::ErrorCode::ConstraintViolation
                || msg.contains("association in use")
            {
                return Box::new(AssociationInUseError);
            }
        }
    }
    err
}

fn default_ttl_secs() -> i64 {
    std::env::var("DELETION_UNDO_TTL_SECONDS")
        .ok()
        .and_then(|s| s.parse().ok())
        .filter(|n| *n > 0)
        .unwrap_or(DEFAULT_TTL_SECS)
}

fn resource_label(
    conn: &Connection,
    resource_type: &str,
    resource_id: i64,
) -> rusqlite::Result<String> {
    let sql = match resource_type {
        "Farm" => "SELECT name FROM farms WHERE id = ?1",
        "Crop" => "SELECT name FROM crops WHERE id = ?1",
        "Field" => "SELECT name FROM fields WHERE id = ?1",
        "CultivationPlan" => {
            return conn
                .query_row(
                    "SELECT COALESCE(NULLIF(TRIM(plan_name), ''), f.name) \
                     FROM cultivation_plans cp INNER JOIN farms f ON f.id = cp.farm_id \
                     WHERE cp.id = ?1",
                    params![resource_id],
                    |row| row.get::<_, String>(0),
                )
                .or_else(|_| Ok(format!("CultivationPlan #{resource_id}")));
        }
        "Pest" => "SELECT name FROM pests WHERE id = ?1",
        "Fertilize" => "SELECT name FROM fertilizes WHERE id = ?1",
        "Pesticide" => "SELECT name FROM pesticides WHERE id = ?1",
        "AgriculturalTask" => "SELECT name FROM agricultural_tasks WHERE id = ?1",
        "InteractionRule" => "SELECT rule_type || ' ' || source_group FROM interaction_rules WHERE id = ?1",
        "WorkRecord" => "SELECT name FROM work_records WHERE id = ?1",
        _ => return Ok(format!("{resource_type} #{resource_id}")),
    };
    conn.query_row(sql, params![resource_id], |row| row.get(0))
        .or_else(|_| Ok(format!("{resource_type} #{resource_id}")))
}

fn build_snapshot(
    conn: &Connection,
    resource_type: &str,
    resource_id: i64,
) -> rusqlite::Result<Value> {
    match resource_type {
        "Farm" => farm_snapshot(conn, resource_id),
        "Crop" => single_table_snapshot(conn, "Crop", "crops", resource_id),
        "Field" => single_table_snapshot(conn, "Field", "fields", resource_id),
        "CultivationPlan" => cultivation_plan_snapshot(conn, resource_id),
        "Pest" => single_table_snapshot(conn, "Pest", "pests", resource_id),
        "Fertilize" => single_table_snapshot(conn, "Fertilize", "fertilizes", resource_id),
        "Pesticide" => single_table_snapshot(conn, "Pesticide", "pesticides", resource_id),
        "AgriculturalTask" => {
            single_table_snapshot(conn, "AgriculturalTask", "agricultural_tasks", resource_id)
        }
        "InteractionRule" => {
            single_table_snapshot(conn, "InteractionRule", "interaction_rules", resource_id)
        }
        "WorkRecord" => single_table_snapshot(conn, "WorkRecord", "work_records", resource_id),
        _ => Err(rusqlite::Error::InvalidParameterName(
            resource_type.into(),
        )),
    }
}

pub fn master_table_name(resource_type: &str) -> rusqlite::Result<&'static str> {
    match resource_type {
        "Pest" => Ok("pests"),
        "Fertilize" => Ok("fertilizes"),
        "Pesticide" => Ok("pesticides"),
        "AgriculturalTask" => Ok("agricultural_tasks"),
        "InteractionRule" => Ok("interaction_rules"),
        _ => Err(rusqlite::Error::InvalidParameterName(resource_type.into())),
    }
}

fn resource_dom_id(resource_type: &str, resource_id: i64) -> String {
    match resource_type {
        "CultivationPlan" => format!("cultivation_plan_{resource_id}"),
        other => format!("{}_{}", other.to_lowercase(), resource_id),
    }
}

fn cultivation_plan_snapshot(conn: &Connection, plan_id: i64) -> rusqlite::Result<Value> {
    let plan_attrs = read_row_map(
        conn,
        "SELECT * FROM cultivation_plans WHERE id = ?1",
        params![plan_id],
    )?;
    let mut fields = Vec::new();
    let mut stmt =
        conn.prepare("SELECT * FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1")?;
    let mut rows = stmt.query(params![plan_id])?;
    while let Some(row) = rows.next()? {
        fields.push(json!({
            "model": "CultivationPlanField",
            "attributes": row_map(row)?,
            "associations": {}
        }));
    }
    let mut crops = Vec::new();
    let mut stmt =
        conn.prepare("SELECT * FROM cultivation_plan_crops WHERE cultivation_plan_id = ?1")?;
    let mut rows = stmt.query(params![plan_id])?;
    while let Some(row) = rows.next()? {
        crops.push(json!({
            "model": "CultivationPlanCrop",
            "attributes": row_map(row)?,
            "associations": {}
        }));
    }
    let mut fcs = Vec::new();
    let mut stmt =
        conn.prepare("SELECT * FROM field_cultivations WHERE cultivation_plan_id = ?1")?;
    let mut rows = stmt.query(params![plan_id])?;
    while let Some(row) = rows.next()? {
        fcs.push(json!({
            "model": "FieldCultivation",
            "attributes": row_map(row)?,
            "associations": {}
        }));
    }
    let mut task_schedules = Vec::new();
    let mut stmt = conn.prepare("SELECT * FROM task_schedules WHERE cultivation_plan_id = ?1")?;
    let mut rows = stmt.query(params![plan_id])?;
    while let Some(row) = rows.next()? {
        let schedule_attrs = row_map(row)?;
        let schedule_id = schedule_attrs
            .get("id")
            .and_then(|v| v.as_i64())
            .ok_or_else(|| rusqlite::Error::InvalidParameterName("task_schedule.id".into()))?;
        let mut items = Vec::new();
        let mut item_stmt =
            conn.prepare("SELECT * FROM task_schedule_items WHERE task_schedule_id = ?1")?;
        let mut item_rows = item_stmt.query(params![schedule_id])?;
        while let Some(item_row) = item_rows.next()? {
            items.push(json!({
                "model": "TaskScheduleItem",
                "attributes": row_map(item_row)?,
                "associations": {}
            }));
        }
        task_schedules.push(json!({
            "model": "TaskSchedule",
            "attributes": schedule_attrs,
            "associations": {
                "task_schedule_items": items
            }
        }));
    }
    let mut work_records = Vec::new();
    let mut stmt = conn.prepare("SELECT * FROM work_records WHERE cultivation_plan_id = ?1")?;
    let mut rows = stmt.query(params![plan_id])?;
    while let Some(row) = rows.next()? {
        work_records.push(json!({
            "model": "WorkRecord",
            "attributes": row_map(row)?,
            "associations": {}
        }));
    }
    Ok(json!({
        "model": "CultivationPlan",
        "attributes": plan_attrs,
        "associations": {
            "cultivation_plan_fields": fields,
            "cultivation_plan_crops": crops,
            "field_cultivations": fcs,
            "task_schedules": task_schedules,
            "work_records": work_records
        }
    }))
}

fn delete_cultivation_plan_graph(conn: &Connection, plan_id: i64) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM work_records WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
    conn.execute(
        "DELETE FROM task_schedule_items WHERE task_schedule_id IN \
         (SELECT id FROM task_schedules WHERE cultivation_plan_id = ?1)",
        params![plan_id],
    )?;
    conn.execute(
        "DELETE FROM task_schedules WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
    conn.execute(
        "DELETE FROM field_cultivations WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
    conn.execute(
        "DELETE FROM cultivation_plan_crops WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
    conn.execute(
        "DELETE FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
    let deleted = conn.execute("DELETE FROM cultivation_plans WHERE id = ?1", params![plan_id])?;
    if deleted == 0 {
        return Err(rusqlite::Error::QueryReturnedNoRows);
    }
    Ok(())
}

fn farm_snapshot(conn: &Connection, farm_id: i64) -> rusqlite::Result<Value> {
    let farm_attrs =
        read_row_map(conn, "SELECT * FROM farms WHERE id = ?1", params![farm_id])?;
    let mut field_nodes = Vec::new();
    let mut stmt = conn.prepare("SELECT * FROM fields WHERE farm_id = ?1")?;
    let mut rows = stmt.query(params![farm_id])?;
    while let Some(row) = rows.next()? {
        let attrs = row_map(row)?;
        field_nodes.push(json!({
            "model": "Field",
            "attributes": attrs,
            "associations": {}
        }));
    }
    Ok(json!({
        "model": "Farm",
        "attributes": farm_attrs,
        "associations": { "fields": field_nodes }
    }))
}

fn single_table_snapshot(
    conn: &Connection,
    model: &str,
    table: &str,
    id: i64,
) -> rusqlite::Result<Value> {
    let sql = format!("SELECT * FROM {table} WHERE id = ?1");
    let attrs = read_row_map(conn, &sql, params![id])?;
    Ok(json!({
        "model": model,
        "attributes": attrs,
        "associations": {}
    }))
}

fn read_row_map(
    conn: &Connection,
    sql: &str,
    params: impl rusqlite::Params,
) -> rusqlite::Result<Map<String, Value>> {
    conn.query_row(sql, params, |row| row_map(row))
}

fn row_map(row: &Row<'_>) -> rusqlite::Result<Map<String, Value>> {
    let mut map = Map::new();
    let names = row.as_ref().column_names();
    for (i, name) in names.iter().enumerate() {
        let value: rusqlite::types::Value = row.get(i)?;
        map.insert((*name).to_string(), sqlite_value_to_json(value));
    }
    Ok(map)
}

fn sqlite_value_to_json(value: rusqlite::types::Value) -> Value {
    match value {
        rusqlite::types::Value::Null => Value::Null,
        rusqlite::types::Value::Integer(i) => json!(i),
        rusqlite::types::Value::Real(f) => json!(f),
        rusqlite::types::Value::Text(s) => Value::String(s),
        rusqlite::types::Value::Blob(b) => Value::String(String::from_utf8_lossy(&b).into_owned()),
    }
}

fn crop_has_restricted_usage(conn: &Connection, crop_id: i64) -> rusqlite::Result<bool> {
    let plan_crops: i64 = conn.query_row(
        "SELECT COUNT(*) FROM cultivation_plan_crops WHERE crop_id = ?1",
        params![crop_id],
        |row| row.get(0),
    )?;
    let free_plans: i64 = conn.query_row(
        "SELECT COUNT(*) FROM free_crop_plans WHERE crop_id = ?1",
        params![crop_id],
        |row| row.get(0),
    )?;
    let pesticides: i64 = conn.query_row(
        "SELECT COUNT(*) FROM pesticides WHERE crop_id = ?1",
        params![crop_id],
        |row| row.get(0),
    )?;
    Ok(plan_crops > 0 || free_plans > 0 || pesticides > 0)
}

fn delete_crop_graph(conn: &Connection, crop_id: i64) -> rusqlite::Result<()> {
    let stage_ids: Vec<i64> = {
        let mut stmt = conn.prepare("SELECT id FROM crop_stages WHERE crop_id = ?1")?;
        let rows = stmt.query_map(params![crop_id], |row| row.get(0))?;
        rows.filter_map(|r| r.ok()).collect()
    };
    for stage_id in stage_ids {
        conn.execute(
            "DELETE FROM temperature_requirements WHERE crop_stage_id = ?1",
            params![stage_id],
        )?;
        conn.execute(
            "DELETE FROM thermal_requirements WHERE crop_stage_id = ?1",
            params![stage_id],
        )?;
        conn.execute(
            "DELETE FROM sunshine_requirements WHERE crop_stage_id = ?1",
            params![stage_id],
        )?;
        conn.execute(
            "DELETE FROM nutrient_requirements WHERE crop_stage_id = ?1",
            params![stage_id],
        )?;
    }
    conn.execute("DELETE FROM crop_stages WHERE crop_id = ?1", params![crop_id])?;
    conn.execute("DELETE FROM crop_pests WHERE crop_id = ?1", params![crop_id])?;
    conn.execute(
        "DELETE FROM crop_task_schedule_blueprints WHERE crop_id = ?1",
        params![crop_id],
    )?;
    conn.execute(
        "DELETE FROM crop_task_templates WHERE crop_id = ?1",
        params![crop_id],
    )?;
    let deleted = conn.execute("DELETE FROM crops WHERE id = ?1", params![crop_id])?;
    if deleted == 0 {
        return Err(rusqlite::Error::QueryReturnedNoRows);
    }
    Ok(())
}

fn new_uuid_v4() -> String {
    let mut b = [0u8; 16];
    getrandom::getrandom(&mut b).expect("getrandom");
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    format!(
        "{:02x}{:02x}{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}{:02x}{:02x}{:02x}{:02x}",
        b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13],
        b[14], b[15]
    )
}
