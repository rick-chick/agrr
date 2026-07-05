//! Ruby: `TaskScheduleTimelineReadActiveRecordGateway` — timeline snapshot assembly.

use crate::cultivation_plan::rest_plan_read::compute_plan_display_name;
use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::normalize_stored_sync_error;
use agrr_domain::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineAgriculturalTaskRead, TaskScheduleTimelineFieldRead,
    TaskScheduleTimelinePlanRead, TaskScheduleTimelineScheduleItemRead,
    TaskScheduleTimelineScheduleRead, TaskScheduleTimelineSnapshot,
    TaskScheduleTimelineTaskOptionRead, TaskScheduleTimelineWorkRecordSummaryRead,
};
use rusqlite::{params, OptionalExtension};
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
                field.task_options = load_task_options(conn, plan_id)?;
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
         COALESCE(f.name, ''), COALESCE(cp.task_schedule_sync_state, 'never'), \
         cp.task_schedule_sync_error, cp.task_schedule_sync_error_crop_id \
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
            row.get::<_, String>(8)?,
            row.get::<_, Option<String>>(9)?,
            row.get::<_, Option<i64>>(10)?,
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

    let (
        id,
        plan_name,
        plan_year,
        status,
        ps,
        pe,
        total_area,
        farm_display_name,
        sync_state,
        sync_error,
        sync_error_crop_id,
    ) = row;
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
        task_schedule_sync_state: sync_state,
        task_schedule_sync_error: normalize_stored_sync_error(sync_error),
        task_schedule_sync_error_crop_id: sync_error_crop_id,
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
         COALESCE(cpc.name, cr.name, ''), COALESCE(fc.area, 0), COALESCE(cpc.crop_id, 0) \
         FROM field_cultivations fc \
         LEFT JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
         LEFT JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
         LEFT JOIN crops cr ON cr.id = cpc.crop_id \
         WHERE fc.cultivation_plan_id = ?1",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok(FieldContext {
            field_cultivation_id: row.get(0)?,
            id: row.get(0)?,
            name: row.get(1)?,
            crop_name: row.get(2)?,
            area_sqm: row.get(3)?,
            crop_id: row.get::<_, i64>(4)?,
        })
    })?;
    rows.collect()
}

fn load_task_options(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<Vec<TaskScheduleTimelineTaskOptionRead>> {
    let mut stmt = conn.prepare(
        "SELECT at.id, at.name, COALESCE(at.task_type, 'field_work'), at.description, \
         at.weather_dependency, at.time_per_sqm, at.required_tools, at.skill_level \
         FROM agricultural_tasks at \
         WHERE at.is_reference = 1 OR at.user_id = ( \
           SELECT f.user_id FROM cultivation_plans cp \
           INNER JOIN farms f ON f.id = cp.farm_id \
           WHERE cp.id = ?1 \
         ) \
         ORDER BY at.name ASC",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok(TaskScheduleTimelineTaskOptionRead {
            agricultural_task_id: row.get(0)?,
            name: row.get(1)?,
            task_type: row.get(2)?,
            description: row.get(3)?,
            weather_dependency: row.get(4)?,
            time_per_sqm: row.get(5)?,
            required_tools: parse_required_tools(row.get(6)?),
            skill_level: row.get(7)?,
        })
    })?;
    rows.collect()
}

fn load_work_record_summaries(
    conn: &rusqlite::Connection,
    plan_id: i64,
) -> rusqlite::Result<std::collections::BTreeMap<i64, Vec<TaskScheduleTimelineWorkRecordSummaryRead>>> {
    let mut stmt = conn.prepare(
        "SELECT wr.task_schedule_item_id, wr.id, wr.actual_date, wr.notes \
         FROM work_records wr \
         WHERE wr.cultivation_plan_id = ?1 AND wr.task_schedule_item_id IS NOT NULL \
         ORDER BY wr.task_schedule_item_id, wr.actual_date ASC",
    )?;
    let rows = stmt.query_map(params![plan_id], |row| {
        Ok((
            row.get::<_, i64>(0)?,
            TaskScheduleTimelineWorkRecordSummaryRead {
                id: row.get(1)?,
                actual_date: row.get(2)?,
                notes: row.get(3)?,
            },
        ))
    })?;
    let mut out: std::collections::BTreeMap<i64, Vec<TaskScheduleTimelineWorkRecordSummaryRead>> =
        std::collections::BTreeMap::new();
    for row in rows {
        let (item_id, record) = row?;
        out.entry(item_id).or_default().push(record);
    }
    Ok(out)
}

fn load_schedule_rows(
    conn: &rusqlite::Connection,
    plan_id: i64,
    work_records_by_item: &std::collections::BTreeMap<
        i64,
        Vec<TaskScheduleTimelineWorkRecordSummaryRead>,
    >,
) -> rusqlite::Result<Vec<(i64, TaskScheduleTimelineScheduleRead)>> {
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

        let agricultural_task = if at_name.is_some() {
            Some(TaskScheduleTimelineAgriculturalTaskRead {
                name: at_name.unwrap(),
                description: row.get(21)?,
                time_per_sqm: row.get(22)?,
                weather_dependency: row.get(23)?,
                required_tools: parse_required_tools(row.get(24)?),
                skill_level: row.get(25)?,
                task_type: row.get(26)?,
            })
        } else {
            None
        };

        let work_records = work_records_by_item
            .get(&item_id)
            .cloned()
            .unwrap_or_default();
        let completed = !work_records.is_empty();

        let item = TaskScheduleTimelineScheduleItemRead {
            id: item_id,
            name,
            task_type,
            scheduled_date,
            stage_name,
            stage_order,
            gdd_trigger,
            gdd_tolerance,
            priority,
            source,
            weather_dependency,
            time_per_sqm,
            amount,
            amount_unit,
            status,
            agricultural_task_id,
            field_cultivation_id,
            agricultural_task,
            rescheduled_at,
            cancelled_at,
            completed,
            work_records,
        };

        Ok((
            field_cultivation_id,
            TaskScheduleTimelineScheduleRead {
                category,
                items: vec![item],
            },
        ))
    })?;

    let mut merged: std::collections::BTreeMap<(i64, String), Vec<TaskScheduleTimelineScheduleItemRead>> =
        std::collections::BTreeMap::new();
    for row in rows {
        let (fc_id, schedule) = row?;
        let key = (fc_id, schedule.category);
        let entry = merged.entry(key).or_default();
        entry.extend(schedule.items);
    }

    let mut out = Vec::new();
    for ((fc_id, category), items) in merged {
        out.push((
            fc_id,
            TaskScheduleTimelineScheduleRead { category, items },
        ));
    }
    Ok(out)
}

fn merge_fields(
    contexts: Vec<FieldContext>,
    schedule_rows: Vec<(i64, TaskScheduleTimelineScheduleRead)>,
) -> Vec<TaskScheduleTimelineFieldRead> {
    let mut schedules_by_fc: std::collections::BTreeMap<i64, Vec<TaskScheduleTimelineScheduleRead>> =
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

fn parse_required_tools(raw: Option<String>) -> Option<Vec<String>> {
    let raw = raw?;
    if let Ok(values) = serde_json::from_str::<Vec<String>>(&raw) {
        return Some(values);
    }
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(&raw) {
        if let Some(arr) = value.as_array() {
            return Some(
                arr.iter()
                    .filter_map(|entry| entry.as_str().map(String::from))
                    .collect(),
            );
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pool::SqlitePool;

    const TIMELINE_DDL: &str = "
CREATE TABLE farms (id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT);
CREATE TABLE cultivation_plans (
  id INTEGER PRIMARY KEY, farm_id INTEGER, plan_name TEXT, plan_year INTEGER,
  status TEXT, planning_start_date TEXT, planning_end_date TEXT, total_area REAL,
  task_schedule_sync_state TEXT, task_schedule_sync_error TEXT,
  task_schedule_sync_error_crop_id INTEGER
);
CREATE TABLE cultivation_plan_fields (
  id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, name TEXT
);
CREATE TABLE cultivation_plan_crops (
  id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, name TEXT, crop_id INTEGER
);
CREATE TABLE crops (id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE field_cultivations (
  id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER,
  cultivation_plan_field_id INTEGER, cultivation_plan_crop_id INTEGER, area REAL
);
CREATE TABLE agricultural_tasks (
  id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER NOT NULL DEFAULT 0,
  name TEXT NOT NULL, task_type TEXT, description TEXT, weather_dependency TEXT,
  time_per_sqm REAL, required_tools TEXT, skill_level TEXT
);
CREATE TABLE task_schedules (
  id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, field_cultivation_id INTEGER,
  category TEXT NOT NULL, generated_at TEXT
);
CREATE TABLE task_schedule_items (
  id INTEGER PRIMARY KEY, task_schedule_id INTEGER, name TEXT, task_type TEXT,
  scheduled_date TEXT, stage_name TEXT, stage_order INTEGER, gdd_trigger REAL,
  gdd_tolerance REAL, priority INTEGER, source TEXT, weather_dependency TEXT,
  time_per_sqm REAL, amount REAL, amount_unit TEXT, status TEXT,
  agricultural_task_id INTEGER, rescheduled_at TEXT, cancelled_at TEXT
);
CREATE TABLE work_records (
  id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, task_schedule_item_id INTEGER,
  actual_date TEXT, notes TEXT
);
";

    fn temp_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_ts_tl_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "ts_tl_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(TIMELINE_DDL)?;
            conn.execute(
                "INSERT INTO farms (id, user_id, name) VALUES (1, 7, 'Farm A')",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, plan_name, plan_year, status, total_area, task_schedule_sync_state)
                 VALUES (1, 1, 'Plan', 2026, 'completed', 100.0, 'synced')",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name) VALUES (10, 1, 'Field 1')",
                [],
            )?;
            conn.execute(
                "INSERT INTO crops (id, name) VALUES (42, 'Tomato')",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plan_crops (id, cultivation_plan_id, name, crop_id) VALUES (20, 1, 'Tomato', 42)",
                [],
            )?;
            conn.execute(
                "INSERT INTO field_cultivations (id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, area)
                 VALUES (100, 1, 10, 20, 50.0)",
                [],
            )?;
            conn.execute(
                "INSERT INTO agricultural_tasks (id, user_id, is_reference, name, task_type, required_tools)
                 VALUES (501, 7, 0, 'Weeding', 'field_work', '[\"hoe\"]')",
                [],
            )?;
            conn.execute(
                "INSERT INTO task_schedules (id, cultivation_plan_id, field_cultivation_id, category, generated_at)
                 VALUES (900, 1, 100, 'general', '2026-07-01T00:00:00Z')",
                [],
            )?;
            conn.execute(
                "INSERT INTO task_schedule_items (id, task_schedule_id, name, task_type, scheduled_date, source, status, agricultural_task_id)
                 VALUES (1001, 900, 'Weed', 'field_work', '2026-07-05', 'agrr', 'planned', 501)",
                [],
            )?;
            conn.execute(
                "INSERT INTO work_records (id, cultivation_plan_id, task_schedule_item_id, actual_date, notes)
                 VALUES (2001, 1, 1001, '2026-07-05', 'done')",
                [],
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn load_snapshot_assembles_typed_task_options_and_schedule_rows() {
        let pool = temp_pool();
        let snapshot = load_task_schedule_timeline_snapshot(&pool, 1).expect("snapshot");

        assert_eq!(snapshot.plan.id, 1);
        assert_eq!(snapshot.plan.display_name, "Plan (2026)");
        assert_eq!(snapshot.scheduled_dates.len(), 1);

        let field = snapshot.fields.first().expect("field");
        assert_eq!(field.field_cultivation_id, 100);
        assert_eq!(field.crop_id, 42);
        assert_eq!(field.task_options.len(), 1);
        assert_eq!(field.task_options[0].agricultural_task_id, 501);
        assert_eq!(field.task_options[0].name, "Weeding");
        assert_eq!(
            field.task_options[0].required_tools,
            Some(vec!["hoe".to_string()])
        );

        let schedule = field.schedules.first().expect("schedule");
        assert_eq!(schedule.category, "general");
        let item = schedule.items.first().expect("item");
        assert_eq!(item.id, 1001);
        assert!(item.completed);
        assert_eq!(item.work_records.len(), 1);
        assert_eq!(item.work_records[0].actual_date, "2026-07-05");
        let master = item.agricultural_task.as_ref().expect("master");
        assert_eq!(master.name, "Weeding");
    }
}
