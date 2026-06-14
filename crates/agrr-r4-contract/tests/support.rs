//! Contract test helpers (session login + SQLite seed for work_record scenarios).

use agrr_r4_contract::http::ContractClient;
use rusqlite::params;
use std::collections::HashMap;

pub fn empty_headers() -> HashMap<String, String> {
    HashMap::new()
}

pub fn status_and_body(response: reqwest::blocking::Response) -> (u16, String) {
    let status = response.status().as_u16();
    let body = response.text().expect("response body");
    (status, body)
}

pub fn developer_session_id(client: &ContractClient) -> String {
    let response = client.get("/auth/test/developer", None, &empty_headers());
    for value in response.headers().get_all("set-cookie") {
        if let Ok(raw) = value.to_str() {
            if let Some(rest) = raw.split("session_id=").nth(1) {
                let session_id = rest.split(';').next().unwrap_or(rest);
                return session_id.to_string();
            }
        }
    }
    panic!(
        "session_id cookie missing from /auth/test/developer (status {})",
        response.status()
    );
}

pub fn user_id_for_session(client: &ContractClient, session_id: &str) -> i64 {
    let (status, body) = status_and_body(client.get("/api/v1/auth/me", Some(session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("auth me JSON");
    json["user"]["id"]
        .as_i64()
        .expect("user id in /api/v1/auth/me response")
}

pub struct WorkRecordPlanSeed {
    pub plan_id: i64,
    pub task_schedule_item_id: i64,
}

fn seed_suffix() -> String {
    format!(
        "{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    )
}

/// Seeds a private plan owned by `user_id` with one task schedule item.
pub fn seed_work_record_plan(user_id: i64) -> WorkRecordPlanSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let farm_name = format!("Contract Work Record Farm {suffix}");

    conn.execute(
        "INSERT INTO farms (user_id, name, latitude, longitude, created_at, updated_at, is_reference)
         VALUES (?1, ?2, 35.0, 139.0, datetime('now'), datetime('now'), 0)",
        params![user_id, farm_name],
    )
    .expect("insert farm");
    let farm_id = conn.last_insert_rowid();

    let crop_name = format!("Contract Crop {suffix}");
    conn.execute(
        "INSERT INTO crops (user_id, name, variety, is_reference, created_at, updated_at)
         VALUES (?1, ?2, 'V1', 0, datetime('now'), datetime('now'))",
        params![user_id, crop_name],
    )
    .expect("insert crop");
    let crop_id = conn.last_insert_rowid();

    let task_name = format!("除草 {suffix}");
    conn.execute(
        "INSERT INTO agricultural_tasks (name, is_reference, user_id, task_type, created_at, updated_at)
         VALUES (?1, 0, ?2, 'field_work', datetime('now'), datetime('now'))",
        params![task_name, user_id],
    )
    .expect("insert agricultural_task");
    let agricultural_task_id = conn.last_insert_rowid();

    let plan_name = format!("Contract Work Record Plan {suffix}");
    conn.execute(
        "INSERT INTO cultivation_plans (
           farm_id, user_id, total_area, plan_type, plan_year, plan_name,
           planning_start_date, planning_end_date, status, created_at, updated_at
         ) VALUES (
           ?1, ?2, 50.0, 'private', 2026, ?3,
           '2026-01-01', '2026-12-31', 'completed', datetime('now'), datetime('now')
         )",
        params![farm_id, user_id, plan_name],
    )
    .expect("insert cultivation_plan");
    let plan_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO cultivation_plan_fields (cultivation_plan_id, name, area, created_at, updated_at)
         VALUES (?1, 'F1', 50.0, datetime('now'), datetime('now'))",
        params![plan_id],
    )
    .expect("insert plan field");
    let plan_field_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO cultivation_plan_crops (cultivation_plan_id, crop_id, name, created_at, updated_at)
         VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
        params![plan_id, crop_id, crop_name],
    )
    .expect("insert plan crop");
    let plan_crop_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO field_cultivations (
           cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id,
           area, status, created_at, updated_at
         ) VALUES (?1, ?2, ?3, 50.0, 'completed', datetime('now'), datetime('now'))",
        params![plan_id, plan_field_id, plan_crop_id],
    )
    .expect("insert field_cultivation");
    let field_cultivation_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO task_schedules (
           cultivation_plan_id, field_cultivation_id, category, status, source,
           generated_at, created_at, updated_at
         ) VALUES (?1, ?2, 'general', 'active', 'agrr', datetime('now'), datetime('now'), datetime('now'))",
        params![plan_id, field_cultivation_id],
    )
    .expect("insert task_schedule");
    let task_schedule_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO task_schedule_items (
           task_schedule_id, task_type, name, source, stage_name, stage_order,
           scheduled_date, amount, amount_unit, agricultural_task_id, status,
           created_at, updated_at
         ) VALUES (
           ?1, 'field_work', '除草作業', 'agrr', '初期', 1,
           '2026-06-02', 2.5, 'kg', ?2, 'planned',
           datetime('now'), datetime('now')
         )",
        params![task_schedule_id, agricultural_task_id],
    )
    .expect("insert task_schedule_item");
    let task_schedule_item_id = conn.last_insert_rowid();

    WorkRecordPlanSeed {
        plan_id,
        task_schedule_item_id,
    }
}
