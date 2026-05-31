//! Restore rows from Rails-compatible deletion undo snapshots.

use rusqlite::{Connection, Row};
use serde_json::{Map, Value};
use std::collections::HashSet;

use crate::shared::attr_sql::quote_sql_column;

use super::schedule::master_table_name;

pub fn restore_snapshot(
    conn: &Connection,
    snapshot: &Value,
) -> Result<(), rusqlite::Error> {
    restore_node(conn, snapshot)
}

fn restore_node(conn: &Connection, node: &Value) -> Result<(), rusqlite::Error> {
    let model = node
        .get("model")
        .and_then(|v| v.as_str())
        .ok_or_else(|| rusqlite::Error::InvalidParameterName("snapshot.model".into()))?;
    let attributes = node
        .get("attributes")
        .and_then(|v| v.as_object())
        .ok_or_else(|| rusqlite::Error::InvalidParameterName("snapshot.attributes".into()))?;
    let table = table_for_model(model)?;
    insert_attributes(conn, table, attributes)?;

    if let Some(associations) = node.get("associations").and_then(|v| v.as_object()) {
        for (name, child) in associations {
            match (model, name.as_str()) {
                ("Farm", "fields") => restore_children(conn, child)?,
                ("CultivationPlan", "cultivation_plan_fields")
                | ("CultivationPlan", "cultivation_plan_crops")
                | ("CultivationPlan", "field_cultivations")
                | ("CultivationPlan", "task_schedules") => restore_children(conn, child)?,
                _ => {}
            }
        }
    }
    Ok(())
}

fn restore_children(conn: &Connection, child: &Value) -> Result<(), rusqlite::Error> {
    match child {
        Value::Array(items) => {
            for item in items {
                restore_node(conn, item)?;
            }
        }
        Value::Object(_) => restore_node(conn, child)?,
        _ => {}
    }
    Ok(())
}

fn table_for_model(model: &str) -> Result<&'static str, rusqlite::Error> {
    match model {
        "Farm" => Ok("farms"),
        "Crop" => Ok("crops"),
        "Field" => Ok("fields"),
        "CultivationPlan" => Ok("cultivation_plans"),
        "CultivationPlanField" => Ok("cultivation_plan_fields"),
        "CultivationPlanCrop" => Ok("cultivation_plan_crops"),
        "FieldCultivation" => Ok("field_cultivations"),
        "TaskSchedule" => Ok("task_schedules"),
        "Pest" | "Fertilize" | "Pesticide" | "AgriculturalTask" | "InteractionRule" => {
            master_table_name(model)
        }
        other => Err(rusqlite::Error::InvalidParameterName(other.into())),
    }
}

fn insert_attributes(
    conn: &Connection,
    table: &str,
    attributes: &Map<String, Value>,
) -> Result<(), rusqlite::Error> {
    if attributes.is_empty() {
        return Ok(());
    }
    let existing: HashSet<String> = table_columns(conn, table)?
        .into_iter()
        .collect();
    let keys: Vec<&String> = attributes
        .keys()
        .filter(|k| existing.contains(k.as_str()))
        .collect();
    if keys.is_empty() && !attributes.is_empty() {
        return Err(rusqlite::Error::InvalidParameterName(format!(
            "no matching columns for table {table}"
        )));
    }
    if keys.is_empty() {
        return Ok(());
    }
    let quoted_cols: Vec<String> = keys
        .iter()
        .map(|k| quote_sql_column(k).into_owned())
        .collect();
    let placeholders: Vec<String> = (1..=quoted_cols.len()).map(|i| format!("?{i}")).collect();
    let sql = format!(
        "INSERT OR REPLACE INTO {table} ({}) VALUES ({})",
        quoted_cols.join(", "),
        placeholders.join(", ")
    );
    let params: Vec<rusqlite::types::Value> = keys
        .iter()
        .map(|k| json_to_sqlite(attributes.get(*k).unwrap_or(&Value::Null)))
        .collect();
    conn.execute(&sql, rusqlite::params_from_iter(params))?;
    Ok(())
}

fn table_columns(conn: &Connection, table: &str) -> Result<Vec<String>, rusqlite::Error> {
    let sql = format!("PRAGMA table_info({table})");
    let mut stmt = conn.prepare(&sql)?;
    let names = stmt
        .query_map([], |row: &Row<'_>| row.get::<_, String>(1))?
        .collect::<Result<Vec<_>, _>>()?;
    Ok(names)
}

fn json_to_sqlite(value: &Value) -> rusqlite::types::Value {
    match value {
        Value::Null => rusqlite::types::Value::Null,
        Value::Bool(b) => rusqlite::types::Value::Integer(i64::from(*b)),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                rusqlite::types::Value::Integer(i)
            } else {
                rusqlite::types::Value::Real(n.as_f64().unwrap_or(0.0))
            }
        }
        Value::String(s) => rusqlite::types::Value::Text(s.clone()),
        other => rusqlite::types::Value::Text(other.to_string()),
    }
}
