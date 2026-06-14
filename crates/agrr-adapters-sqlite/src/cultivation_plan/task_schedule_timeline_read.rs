//! Ruby: `TaskScheduleTimelineReadActiveRecordGateway` — timeline snapshot assembly.

use crate::cultivation_plan::rest_plan_read::compute_plan_display_name;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineFieldRead, TaskScheduleTimelinePlanRead, TaskScheduleTimelineSnapshot,
};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use time::{Date, format_description::well_known::Iso8601};

pub fn load_task_schedule_timeline_snapshot(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<TaskScheduleTimelineSnapshot, Box<dyn std::error::Error + Send + Sync>> {
    pool.with_read_box(|conn| {
        let plan = load_plan_read(conn, plan_id)?;
        let scheduled_dates = load_scheduled_dates(conn, plan_id)?;
        let field_contexts = load_field_contexts(conn, plan_id)?;
        let work_records_by_item = load_work_record_summaries(conn, plan_id)?;
        let schedule_rows = load_schedule_rows(conn, plan_id, &work_records_by_item)?;
        let mut fields = merge_fields(field_contexts, schedule_rows);
        for field in &mut fields {
            if field.crop_id > 0 {
                field.task_options = load_task_options(conn, field.crop_id)?;
            }
        }
        Ok(TaskScheduleTimelineSnapshot {
            plan,
            fields,
            scheduled_dates,
        })
    })
}

fn load_plan_read(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<TaskScheduleTimelinePlanRead> {
    let mut stmt = conn.prepare(
        "SELECT cp.id, cp.plan_name, cp.plan_year, cp.status, \
         cp.planning_start_date, cp.planning_end_date, COALESCE(cp.total_area, 0), \
         COALESCE(f.name, '') \
         FROM cultivation_plans cp \
         LEFT JOIN farms f ON f.id = cp.farm_id \
         WHERE cp.id = ?1 LIMIT 1",
    )?;
    let row = stmt.query_row(params![plan_id], |row| {
        Ok((
            row.get::<_, i64>(0)?,
            row.get::<_, Option<String>>(1)?,
            row.get::<_, Option<i32>>(2)?,
            row.get::<_, String>(3)?,
            row.get::<_, Option<String>>(4)?,
            row.get::<_, Option<String>>(5)?,
            row.get::<_, f64>(6)?,
            row.get::<_, String>(7)?,
        ))
    })?;

    let timeline_generated_at: Option<String> = conn
        .query_row(
            "SELECT MAX(generated_at) FROM task_schedules WHERE cultivation_plan_id = ?1",
            params![plan_id],
            |row| row.get(0),
        )
        .optional()?
        .flatten();

    let (id, plan_name, plan_year, status, ps, pe, total_area, farm_display_name) = row;
    let display_name = compute_plan_display_name(id, plan_name.as_deref(), plan_year, &farm_display_name);
    Ok(TaskScheduleTimelinePlanRead {
        id,
        display_name,
        status,
        planning_start_date: parse_date_opt(ps.as_deref()),
        planning_end_date: parse_date_opt(pe.as_deref()),
        timeline_generated_at,
        farm_display_name,
        total_area,
    })
}

fn load_scheduled_dates(conn: &rusqlite::Connection, plan_id: i64) -> rusqlite::Result<Vec<Date>> {
    let mut stmt = conn.prepare(
        "SELECT DISTINCT tsi.scheduled_date \
         FROM task_schedule_items tsi \
         INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
         WHERE ts.cultivation_plan_id = ?1 AND tsi.scheduled_date IS NOT NULL",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        let s: String = row.get(0)?;
        Ok(s)
    })?;
    let mut out = Vec::new();
    for s in rows.flatten() {
        if let Ok(d) = Date::parse(&s, &Iso8601::DATE) {
            out.push(d);
        }
    }
    Ok(out)
}

struct FieldContext {
    field_cultivation_id: i64,
    id: i64,
    name: String,
    crop_name: String,
    area_sqm: f64,
    crop_id: i64,
}

fn load_field_contexts(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<Vec<FieldContext>> {
    let mut stmt = conn.prepare(
        "SELECT DISTINCT fc.id, COALESCE(cpf.name, ''), \
         COALESCE(cpc.name, cr.name, ''), COALESCE(fc.area, 0), cpc.crop_id \
         FROM task_schedules ts \
         INNER JOIN field_cultivations fc ON fc.id = ts.field_cultivation_id \
         LEFT JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
         LEFT JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
         LEFT JOIN crops cr ON cr.id = cpc.crop_id \
         WHERE ts.cultivation_plan_id = ?1",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok(FieldContext {
            field_cultivation_id: row.get(0)?,
            id: row.get(0)?,
            name: row.get(1)?,
            crop_name: row.get(2)?,
            area_sqm: row.get(3)?,
            crop_id: row.get::<_, Option<i64>>(4)?.unwrap_or(0),
        })
    })?;
    rows.collect()
}

fn load_task_options(conn: &rusqlite::Connection, crop_id: i64) -> rusqlite::Result<Vec<Value>> {
    let mut stmt = conn.prepare(
        "SELECT ctt.id, ctt.name, COALESCE(ctt.task_type, 'field_work'), ctt.agricultural_task_id, \
         ctt.description, ctt.weather_dependency, ctt.time_per_sqm, ctt.required_tools, ctt.skill_level \
         FROM crop_task_templates ctt \
         WHERE ctt.crop_id = ?1 \
         ORDER BY ctt.name ASC",
    )?;
    let rows = stmt.query_map(params![crop_id], |row| {
        let template_id: i64 = row.get(0)?;
        let name: String = row.get(1)?;
        let task_type: String = row.get(2)?;
        let agricultural_task_id: Option<i64> = row.get(3)?;
        let description: Option<String> = row.get(4)?;
        let weather_dependency: Option<String> = row.get(5)?;
        let time_per_sqm: Option<f64> = row.get(6)?;
        let required_tools: Option<String> = row.get(7)?;
        let skill_level: Option<String> = row.get(8)?;
        let mut obj = json!({
            "template_id": template_id,
            "name": name,
            "task_type": task_type,
        });
        if let Some(v) = agricultural_task_id {
            obj["agricultural_task_id"] = json!(v);
        }
        if let Some(v) = description {
            obj["description"] = json!(v);
        }
        if let Some(v) = weather_dependency {
            obj["weather_dependency"] = json!(v);
        }
        if let Some(v) = time_per_sqm {
            obj["time_per_sqm"] = json!(v.to_string());
        }
        if let Some(v) = required_tools {
            if let Ok(arr) = serde_json::from_str::<Value>(&v) {
                obj["required_tools"] = arr;
            }
        }
        if let Some(v) = skill_level {
            obj["skill_level"] = json!(v);
        }
        Ok(obj)
    })?;
    rows.collect()
}

fn load_work_record_summaries(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<std::collections::BTreeMap<i64, Vec<Value>>> {
    let mut stmt = conn.prepare(
        "SELECT wr.task_schedule_item_id, wr.id, wr.actual_date, wr.notes \
         FROM work_records wr \
         WHERE wr.cultivation_plan_id = ?1 AND wr.task_schedule_item_id IS NOT NULL \
         ORDER BY wr.task_schedule_item_id, wr.actual_date ASC",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        let item_id: i64 = row.get(0)?;
        let record = json!({
            "id": row.get::<_, i64>(1)?,
            "actual_date": row.get::<_, String>(2)?,
            "notes": row.get::<_, Option<String>>(3)?,
        });
        Ok((item_id, record))
    })?;
    let mut out: std::collections::BTreeMap<i64, Vec<Value>> = std::collections::BTreeMap::new();
    for row in rows {
        let (item_id, record) = row?;
        out.entry(item_id).or_default().push(record);
    }
    Ok(out)
}

fn load_schedule_rows(
    conn: &rusqlite::Connection,
    plan_id: i64,
    work_records_by_item: &std::collections::BTreeMap<i64, Vec<Value>>,
) -> rusqlite::Result<Vec<(i64, Value)>> {
    let mut stmt = conn.prepare(
        "SELECT ts.field_cultivation_id, ts.category, tsi.id, tsi.name, tsi.task_type, tsi.scheduled_date, \
         tsi.stage_name, tsi.stage_order, tsi.gdd_trigger, tsi.gdd_tolerance, tsi.priority, tsi.source, \
         tsi.weather_dependency, tsi.time_per_sqm, tsi.amount, tsi.amount_unit, tsi.status, \
         tsi.agricultural_task_id, tsi.rescheduled_at, tsi.cancelled_at, \
         at.name, at.description, at.time_per_sqm, at.weather_dependency, at.required_tools, \
         at.skill_level, at.task_type \
         FROM task_schedules ts \
         INNER JOIN task_schedule_items tsi ON tsi.task_schedule_id = ts.id \
         LEFT JOIN agricultural_tasks at ON at.id = tsi.agricultural_task_id \
         WHERE ts.cultivation_plan_id = ?1 \
         ORDER BY ts.field_cultivation_id, ts.category, tsi.scheduled_date",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        let field_cultivation_id: i64 = row.get(0)?;
        let category: String = row.get(1)?;
        let item_id: i64 = row.get(2)?;
        let name: String = row.get(3)?;
        let task_type: String = row.get(4)?;
        let scheduled_date: Option<String> = row.get(5)?;
        let stage_name: Option<String> = row.get(6)?;
        let stage_order: Option<i32> = row.get(7)?;
        let gdd_trigger: Option<f64> = row.get(8)?;
        let gdd_tolerance: Option<f64> = row.get(9)?;
        let priority: Option<i32> = row.get(10)?;
        let source: String = row.get(11)?;
        let weather_dependency: Option<String> = row.get(12)?;
        let time_per_sqm: Option<f64> = row.get(13)?;
        let amount: Option<f64> = row.get(14)?;
        let amount_unit: Option<String> = row.get(15)?;
        let status: String = row.get(16)?;
        let agricultural_task_id: Option<i64> = row.get(17)?;
        let rescheduled_at: Option<String> = row.get(18)?;
        let cancelled_at: Option<String> = row.get(19)?;
        let at_name: Option<String> = row.get(20)?;

        let mut agricultural_task = None;
        if at_name.is_some() {
            let mut at_obj = json!({ "name": at_name.unwrap() });
            if let Some(v) = row.get::<_, Option<String>>(21)? {
                at_obj["description"] = json!(v);
            }
            if let Some(v) = row.get::<_, Option<f64>>(22)? {
                at_obj["time_per_sqm"] = json!(v.to_string());
            }
            if let Some(v) = row.get::<_, Option<String>>(23)? {
                at_obj["weather_dependency"] = json!(v);
            }
            if let Some(v) = row.get::<_, Option<String>>(24)? {
                if let Ok(arr) = serde_json::from_str::<Value>(&v) {
                    at_obj["required_tools"] = arr;
                }
            }
            if let Some(v) = row.get::<_, Option<String>>(25)? {
                at_obj["skill_level"] = json!(v);
            }
            if let Some(v) = row.get::<_, Option<String>>(26)? {
                at_obj["task_type"] = json!(v);
            }
            agricultural_task = Some(at_obj);
        }

        let work_records = work_records_by_item
            .get(&item_id)
            .cloned()
            .unwrap_or_default();
        let completed = !work_records.is_empty();

        let item = json!({
            "id": item_id,
            "name": name,
            "task_type": task_type,
            "scheduled_date": scheduled_date,
            "stage_name": stage_name,
            "stage_order": stage_order,
            "gdd_trigger": gdd_trigger.map(|v| v.to_string()),
            "gdd_tolerance": gdd_tolerance.map(|v| v.to_string()),
            "priority": priority,
            "source": source,
            "weather_dependency": weather_dependency,
            "time_per_sqm": time_per_sqm.map(|v| v.to_string()),
            "amount": amount.map(|v| v.to_string()),
            "amount_unit": amount_unit,
            "status": status,
            "agricultural_task_id": agricultural_task_id,
            "field_cultivation_id": field_cultivation_id,
            "agricultural_task": agricultural_task,
            "rescheduled_at": rescheduled_at,
            "cancelled_at": cancelled_at,
            "completed": completed,
            "work_records": work_records,
        });

        Ok((field_cultivation_id, json!({ "category": category, "items": [item] })))
    })?;

    let mut merged: std::collections::BTreeMap<(i64, String), Vec<Value>> =
        std::collections::BTreeMap::new();
    for row in rows {
        let (fc_id, schedule) = row?;
        let category = schedule["category"].as_str().unwrap_or("general").to_string();
        let key = (fc_id, category);
        let entry = merged.entry(key).or_default();
        if let Some(items) = schedule.get("items").and_then(|v| v.as_array()) {
            for item in items {
                entry.push(item.clone());
            }
        }
    }

    let mut out = Vec::new();
    for ((fc_id, category), items) in merged {
        out.push((
            fc_id,
            json!({ "category": category, "items": items }),
        ));
    }
    Ok(out)
}

fn merge_fields(
    contexts: Vec<FieldContext>,
    schedule_rows: Vec<(i64, Value)>,
) -> Vec<TaskScheduleTimelineFieldRead> {
    let mut schedules_by_fc: std::collections::BTreeMap<i64, Vec<Value>> =
        std::collections::BTreeMap::new();
    for (fc_id, schedule) in schedule_rows {
        schedules_by_fc
            .entry(fc_id)
            .or_default()
            .push(schedule);
    }

    contexts
        .into_iter()
        .map(|ctx| TaskScheduleTimelineFieldRead {
            id: ctx.id,
            name: ctx.name,
            crop_name: ctx.crop_name,
            area_sqm: ctx.area_sqm,
            field_cultivation_id: ctx.field_cultivation_id,
            crop_id: ctx.crop_id,
            task_options: vec![],
            schedules: schedules_by_fc
                .remove(&ctx.field_cultivation_id)
                .unwrap_or_default(),
        })
        .collect()
}

fn parse_date_opt(s: Option<&str>) -> Option<Date> {
    let s = s?;
    Date::parse(s, &Iso8601::DATE).ok()
}
