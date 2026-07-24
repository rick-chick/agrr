//! Contract test helpers (session login + SQLite seed for work_record scenarios).

use agrr_r4_contract::http::ContractClient;
use rusqlite::params;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};

pub fn empty_headers() -> HashMap<String, String> {
    HashMap::new()
}

pub fn status_and_body(response: reqwest::blocking::Response) -> (u16, String) {
    let status = response.status().as_u16();
    let body = response.text().expect("response body");
    (status, body)
}

/// Asserts built-in generation endpoints return RFC 9745 deprecation metadata.
pub fn assert_builtin_generation_deprecated_headers(
    headers: &reqwest::header::HeaderMap,
    body: &str,
    expected_alternative_fragment: &str,
) {
    assert_eq!(
        Some("@2026-07-18"),
        headers.get("deprecation").and_then(|v| v.to_str().ok()),
        "{body}"
    );
    assert_eq!(
        Some("Sat, 18 Oct 2026 00:00:00 GMT"),
        headers.get("sunset").and_then(|v| v.to_str().ok()),
        "{body}"
    );
    let json: serde_json::Value = serde_json::from_str(body).expect("deprecated JSON");
    assert_eq!(Some(true), json.get("deprecated").and_then(|v| v.as_bool()), "{body}");
    let alternative = json["deprecation"]["alternative"]
        .as_str()
        .unwrap_or_default();
    assert!(
        alternative.contains(expected_alternative_fragment),
        "expected alternative to contain {expected_alternative_fragment}: {body}"
    );
    assert_eq!(
        Some("/docs/api/builtin-generation-sunset.md"),
        json["deprecation"]["migration_guide"].as_str(),
        "{body}"
    );
    assert_eq!(
        Some("2026-10-18"),
        json["deprecation"]["sunset"].as_str(),
        "{body}"
    );
}

/// Asserts deprecated crop agricultural_tasks API returns 410 Gone.
pub fn assert_crop_task_template_api_removed(status: u16, body: &str) {
    assert_eq!(410, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(body).expect("gone JSON");
    assert_eq!(
        json.get("error_code").and_then(|v| v.as_str()),
        Some("crop_task_template_api_removed"),
        "{body}"
    );
    assert!(json.get("error").is_some(), "{body}");
}

fn session_id_from_mock_login_response(response: reqwest::blocking::Response, route: &str) -> String {
    for value in response.headers().get_all("set-cookie") {
        if let Ok(raw) = value.to_str() {
            if let Some(rest) = raw.split("session_id=").nth(1) {
                let session_id = rest.split(';').next().unwrap_or(rest);
                return session_id.to_string();
            }
        }
    }
    panic!(
        "session_id cookie missing from {route} (status {})",
        response.status()
    );
}

pub fn developer_session_id(client: &ContractClient) -> String {
    let response = client.get("/auth/test/developer", None, &empty_headers());
    session_id_from_mock_login_response(response, "/auth/test/developer")
}

/// Non-admin mock user (`/auth/test/mock_login_as/farmer`).
pub fn farmer_session_id(client: &ContractClient) -> String {
    let response = client.get("/auth/test/mock_login_as/farmer", None, &empty_headers());
    session_id_from_mock_login_response(response, "/auth/test/mock_login_as/farmer")
}

/// Non-admin mock user (`/auth/test/mock_login_as/researcher`).
pub fn researcher_session_id(client: &ContractClient) -> String {
    let response = client.get("/auth/test/mock_login_as/researcher", None, &empty_headers());
    session_id_from_mock_login_response(response, "/auth/test/mock_login_as/researcher")
}

pub fn user_id_for_session(client: &ContractClient, session_id: &str) -> i64 {
    let (status, body) = status_and_body(client.get("/api/v1/auth/me", Some(session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("auth me JSON");
    json["user"]["id"]
        .as_i64()
        .expect("user id in /api/v1/auth/me response")
}

/// Frees a farm-create slot when earlier contract seeds filled the per-user non-reference limit.
pub fn ensure_farm_create_capacity_via_api(client: &ContractClient, session_id: &str) {
    const MAX_NON_REFERENCE_FARMS_PER_USER: usize = 4;

    loop {
        let (status, body) =
            status_and_body(client.get("/api/v1/masters/farms", Some(session_id), &empty_headers()));
        assert_eq!(200, status, "{body}");
        let farms: Vec<serde_json::Value> = serde_json::from_str(&body).expect("farm list JSON");
        let non_reference: Vec<i64> = farms
            .iter()
            .filter(|farm| farm["is_reference"].as_bool() == Some(false))
            .filter_map(|farm| farm["id"].as_i64())
            .collect();
        if non_reference.len() < MAX_NON_REFERENCE_FARMS_PER_USER {
            break;
        }
        let farm_id = *non_reference.iter().min().expect("farm id to delete");
        let path = format!("/api/v1/masters/farms/{farm_id}");
        let (delete_status, delete_body) =
            status_and_body(client.delete(&path, Some(session_id), &empty_headers()));
        assert_eq!(200, delete_status, "{delete_body}");
    }
}

pub struct WorkRecordPlanSeed {
    pub plan_id: i64,
    pub farm_id: i64,
    pub crop_id: i64,
    pub crop_name: String,
    pub task_schedule_item_id: i64,
}

pub struct MastersCropSeed {
    pub crop_id: i64,
}

pub struct MastersCropStagesSeed {
    pub crop_id: i64,
    pub stage_ids: Vec<i64>,
}

pub struct ReferenceCropStageSeed {
    pub crop_id: i64,
    pub stage_id: i64,
}

/// Seeds a reference crop with one stage for masters edit-authorization contract tests.
pub fn seed_reference_crop_with_stage() -> ReferenceCropStageSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let crop_name = format!("Contract Reference Crop {suffix}");
    conn.execute(
        "INSERT INTO crops (user_id, name, variety, is_reference, created_at, updated_at)
         VALUES (NULL, ?1, 'Ref', 1, datetime('now'), datetime('now'))",
        params![crop_name],
    )
    .expect("insert reference crop");
    let crop_id = conn.last_insert_rowid();
    conn.execute(
        "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at)
         VALUES (?1, 'Ref Stage', 1, datetime('now'), datetime('now'))",
        params![crop_id],
    )
    .expect("insert reference crop stage");
    ReferenceCropStageSeed {
        crop_id,
        stage_id: conn.last_insert_rowid(),
    }
}

pub struct MastersCropStagesBlueprintSeed {
    pub crop_id: i64,
    pub stage_ids: Vec<i64>,
    pub blueprint_ids: Vec<i64>,
}

pub struct MastersCropBlueprintCreateSeed {
    pub crop_id: i64,
    pub agricultural_task_id: i64,
}

/// Seeds a user-owned non-reference crop for masters blueprint API tests.
pub fn seed_masters_crop(user_id: i64) -> MastersCropSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let crop_name = format!("Contract Blueprint Crop {suffix}");
    conn.execute(
        "INSERT INTO crops (user_id, name, variety, is_reference, created_at, updated_at)
         VALUES (?1, ?2, 'V1', 0, datetime('now'), datetime('now'))",
        params![user_id, crop_name],
    )
    .expect("insert crop");
    MastersCropSeed {
        crop_id: conn.last_insert_rowid(),
    }
}

/// Seeds a user-owned crop with multiple stages for crop stage reorder API tests.
pub fn seed_masters_crop_with_stages(user_id: i64, stage_count: i64) -> MastersCropStagesSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let crop_name = format!("Contract Stage Reorder Crop {suffix}");
    conn.execute(
        "INSERT INTO crops (user_id, name, variety, is_reference, created_at, updated_at)
         VALUES (?1, ?2, 'V1', 0, datetime('now'), datetime('now'))",
        params![user_id, crop_name],
    )
    .expect("insert crop");
    let crop_id = conn.last_insert_rowid();
    let mut stage_ids = Vec::new();
    for order in 1..=stage_count {
        conn.execute(
            "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at)
             VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
            params![crop_id, format!("Stage {order}"), order],
        )
        .expect("insert crop stage");
        stage_ids.push(conn.last_insert_rowid());
    }
    MastersCropStagesSeed { crop_id, stage_ids }
}

/// Seeds a crop with two stages and one blueprint per stage order for reorder/delete linkage tests.
pub fn seed_masters_crop_with_stages_and_blueprints(
    user_id: i64,
) -> MastersCropStagesBlueprintSeed {
    let seed = seed_masters_crop_with_stages(user_id, 2);
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let mut blueprint_ids = Vec::new();

    for order in 1..=2 {
        let task_name = format!("Contract Stage Blueprint Task {order} {suffix}");
        conn.execute(
            "INSERT INTO agricultural_tasks (name, is_reference, user_id, task_type, created_at, updated_at)
             VALUES (?1, 0, ?2, 'field_work', datetime('now'), datetime('now'))",
            params![task_name, user_id],
        )
        .expect("insert agricultural_task");
        let agricultural_task_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO crop_task_schedule_blueprints (
                crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance,
                task_type, source, priority, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, 0.0, 5.0, 'field_work', 'manual', 1, datetime('now'), datetime('now'))",
            params![
                seed.crop_id,
                agricultural_task_id,
                order,
                format!("Stage {order}")
            ],
        )
        .expect("insert blueprint");
        blueprint_ids.push(conn.last_insert_rowid());
    }

    MastersCropStagesBlueprintSeed {
        crop_id: seed.crop_id,
        stage_ids: seed.stage_ids,
        blueprint_ids,
    }
}

/// Seeds crop + pending manual blueprint for blueprint create tests.
pub fn seed_masters_crop_with_manual_blueprint(user_id: i64) -> MastersCropBlueprintCreateSeed {
    let crop = seed_masters_crop(user_id);
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let task_name = format!("Contract Blueprint Task {suffix}");
    conn.execute(
        "INSERT INTO agricultural_tasks (name, is_reference, user_id, task_type, created_at, updated_at)
         VALUES (?1, 0, ?2, 'field_work', datetime('now'), datetime('now'))",
        params![task_name, user_id],
    )
    .expect("insert agricultural_task");
    let agricultural_task_id = conn.last_insert_rowid();
    conn.execute(
        "INSERT INTO crop_task_schedule_blueprints (
            crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance,
            task_type, source, priority, name, created_at, updated_at
         ) VALUES (?1, ?2, NULL, NULL, NULL, NULL, 'field_work', 'manual', 1, ?3, datetime('now'), datetime('now'))",
        params![crop.crop_id, agricultural_task_id, task_name],
    )
    .expect("insert manual blueprint");
    MastersCropBlueprintCreateSeed {
        crop_id: crop.crop_id,
        agricultural_task_id,
    }
}

static SEED_SEQ: AtomicU64 = AtomicU64::new(0);

fn seed_suffix() -> String {
    let seq = SEED_SEQ.fetch_add(1, Ordering::Relaxed);
    format!(
        "{}_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos(),
        seq
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

    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Contract Field', 50.0, 0, datetime('now'), datetime('now'))",
        params![farm_id, user_id],
    )
    .expect("insert field");

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
    let _ = conn.execute(
        "UPDATE cultivation_plans SET task_schedule_sync_state = 'ready' WHERE id = ?1",
        params![plan_id],
    );

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
        farm_id,
        crop_id,
        crop_name,
        task_schedule_item_id,
    }
}

/// Sets failed sync state with optional crop context for remediation links.
pub fn set_plan_task_schedule_sync_failed(
    plan_id: i64,
    sync_error: &str,
    sync_error_crop_id: Option<i64>,
) {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    conn.execute(
        "UPDATE cultivation_plans \
         SET task_schedule_sync_state = 'failed', task_schedule_sync_error = ?1, \
             task_schedule_sync_error_crop_id = ?2, updated_at = datetime('now') \
         WHERE id = ?3",
        params![sync_error, sync_error_crop_id, plan_id],
    )
    .expect("update plan sync failed state");
}

/// Sets legacy/raw sync error on an existing plan (contract tests for normalization).
pub fn set_plan_task_schedule_sync_failed_raw_error(plan_id: i64, raw_error: &str) {
    set_plan_task_schedule_sync_failed(plan_id, raw_error, None);
}

/// Removes generated schedules so contract tests can simulate failed-first-generation plans.
pub fn clear_plan_task_schedules(plan_id: i64) {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    conn.execute(
        "DELETE FROM task_schedule_items
         WHERE task_schedule_id IN (
           SELECT id FROM task_schedules WHERE cultivation_plan_id = ?1
         )",
        params![plan_id],
    )
    .expect("delete task_schedule_items");
    conn.execute(
        "DELETE FROM task_schedules WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )
    .expect("delete task_schedules");
}

pub struct TaskScheduleRegenerationSeed {
    pub plan_id: i64,
    pub _field_cultivation_id: i64,
    pub agrr_item_id: i64,
    pub manual_item_id: i64,
    pub completed_item_id: i64,
    pub agricultural_task_id: i64,
}

const CONTRACT_PREDICTED_WEATHER_JSON: &str = r#"{
  "location": { "latitude": 35.0, "longitude": 139.0, "timezone": "Asia/Tokyo" },
  "data": [
    { "time": "2026-01-01T00:00:00", "temperature_2m_mean": 5.0 },
    { "time": "2026-02-01T00:00:00", "temperature_2m_mean": 8.0 },
    { "time": "2026-03-01T00:00:00", "temperature_2m_mean": 12.0 },
    { "time": "2026-04-01T00:00:00", "temperature_2m_mean": 16.0 },
    { "time": "2026-05-01T00:00:00", "temperature_2m_mean": 20.0 },
    { "time": "2026-06-01T00:00:00", "temperature_2m_mean": 24.0 }
  ]
}"#;

fn contract_sqlite_conn() -> rusqlite::Connection {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    rusqlite::Connection::open(&path).expect("open contract sqlite")
}

pub fn seed_predicted_weather_for_plan(plan_id: i64) {
    let conn = contract_sqlite_conn();
    conn.execute(
        "INSERT INTO predicted_weather_metadata \
         (scope, scope_id, prediction_start_date, prediction_end_date, target_end_date, data_end_date, generated_at) \
         VALUES ('plan', ?1, '2026-01-01', '2026-12-31', '2026-12-31', '2026-12-31', datetime('now')) \
         ON CONFLICT(scope, scope_id) DO UPDATE SET \
         prediction_start_date = excluded.prediction_start_date, \
         prediction_end_date = excluded.prediction_end_date, \
         target_end_date = excluded.target_end_date, \
         data_end_date = excluded.data_end_date, \
         generated_at = excluded.generated_at",
        params![plan_id],
    )
    .expect("upsert predicted weather metadata");

    let local_root = std::env::var("WEATHER_DATA_LOCAL_ROOT")
        .unwrap_or_else(|_| "/tmp/agrr-weather-contract".to_string());
    let object_path = format!("{local_root}/predicted_weather/plan/{plan_id}.json");
    if let Some(parent) = std::path::Path::new(&object_path).parent() {
        std::fs::create_dir_all(parent).expect("create weather mirror dir");
    }
    std::fs::write(&object_path, CONTRACT_PREDICTED_WEATHER_JSON).expect("write predicted weather");
}

/// Seeds a plan with blueprints, weather, and mixed schedule items for regeneration tests.
pub fn seed_task_schedule_regeneration_plan(user_id: i64) -> TaskScheduleRegenerationSeed {
    let conn = contract_sqlite_conn();
    let suffix = seed_suffix();
    let farm_name = format!("Contract Regen Farm {suffix}");

    conn.execute(
        "INSERT INTO farms (user_id, name, latitude, longitude, created_at, updated_at, is_reference)
         VALUES (?1, ?2, 35.0, 139.0, datetime('now'), datetime('now'), 0)",
        params![user_id, farm_name],
    )
    .expect("insert farm");
    let farm_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Contract Field', 50.0, 0, datetime('now'), datetime('now'))",
        params![farm_id, user_id],
    )
    .expect("insert field");

    let crop_name = format!("Contract Regen Crop {suffix}");
    conn.execute(
        "INSERT INTO crops (user_id, name, variety, is_reference, area_per_unit, revenue_per_area, groups, created_at, updated_at)
         VALUES (?1, ?2, 'V1', 0, 0.25, 5000.0, '[]', datetime('now'), datetime('now'))",
        params![user_id, crop_name],
    )
    .expect("insert crop");
    let crop_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at)
         VALUES (?1, '生育', 1, datetime('now'), datetime('now'))",
        params![crop_id],
    )
    .expect("insert crop stage");
    let crop_stage_id = conn.last_insert_rowid();
    conn.execute(
        "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, max_temperature, created_at, updated_at)
         VALUES (?1, 10.0, 18.0, 28.0, 35.0, datetime('now'), datetime('now'))",
        params![crop_stage_id],
    )
    .expect("insert temperature requirements");
    conn.execute(
        "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at)
         VALUES (?1, 200.0, datetime('now'), datetime('now'))",
        params![crop_stage_id],
    )
    .expect("insert thermal requirements");

    let task_name = format!("除草 {suffix}");
    conn.execute(
        "INSERT INTO agricultural_tasks (name, is_reference, user_id, task_type, created_at, updated_at)
         VALUES (?1, 0, ?2, 'field_work', datetime('now'), datetime('now'))",
        params![task_name, user_id],
    )
    .expect("insert agricultural_task");
    let agricultural_task_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO crop_task_schedule_blueprints (
           crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance,
           task_type, source, priority, created_at, updated_at
         ) VALUES (?1, ?2, 1, '初期', 0.0, 5.0, 'field_work', 'agrr_schedule', 1, datetime('now'), datetime('now'))",
        params![crop_id, agricultural_task_id],
    )
    .expect("insert blueprint");

    let plan_name = format!("Contract Regen Plan {suffix}");
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
    let _ = conn.execute(
        "UPDATE cultivation_plans SET task_schedule_sync_state = 'ready' WHERE id = ?1",
        params![plan_id],
    );

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
           area, start_date, completion_date, status, created_at, updated_at
         ) VALUES (?1, ?2, ?3, 50.0, '2026-04-01', '2026-10-31', 'completed', datetime('now'), datetime('now'))",
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
           scheduled_date, gdd_trigger, agricultural_task_id, status,
           created_at, updated_at
         ) VALUES (
           ?1, 'field_work', 'agrr予定', 'agrr_schedule', '初期', 1,
           '2026-06-02', 0.0, ?2, 'planned',
           datetime('now'), datetime('now')
         )",
        params![task_schedule_id, agricultural_task_id],
    )
    .expect("insert agrr item");
    let agrr_item_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO task_schedule_items (
           task_schedule_id, task_type, name, source, scheduled_date, gdd_trigger, status,
           created_at, updated_at
         ) VALUES (
           ?1, 'field_work', '手動予定', 'manual_entry',
           '2026-06-10', 0.0, 'planned',
           datetime('now'), datetime('now')
         )",
        params![task_schedule_id],
    )
    .expect("insert manual item");
    let manual_item_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO task_schedule_items (
           task_schedule_id, task_type, name, source, stage_name, stage_order,
           scheduled_date, gdd_trigger, agricultural_task_id, status,
           created_at, updated_at
         ) VALUES (
           ?1, 'field_work', '完了予定', 'agrr_schedule', '初期', 1,
           '2026-06-03', 0.0, ?2, 'planned',
           datetime('now'), datetime('now')
         )",
        params![task_schedule_id, agricultural_task_id],
    )
    .expect("insert completed-bound item");
    let completed_item_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO work_records (
           cultivation_plan_id, field_cultivation_id, task_schedule_item_id,
           agricultural_task_id, name, task_type, actual_date, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, '完了予定', 'field_work', '2026-06-03', datetime('now'), datetime('now'))",
        params![
            plan_id,
            field_cultivation_id,
            completed_item_id,
            agricultural_task_id
        ],
    )
    .expect("insert work record");

    seed_predicted_weather_for_plan(plan_id);

    TaskScheduleRegenerationSeed {
        plan_id,
        _field_cultivation_id: field_cultivation_id,
        agrr_item_id,
        manual_item_id,
        completed_item_id,
        agricultural_task_id,
    }
}

pub fn agrr_regeneration_contract_available() -> bool {
    let agrr_bin =
        std::env::var("AGRR_BIN_PATH").unwrap_or_else(|_| "/app/lib/core/agrr".to_string());
    std::path::Path::new(&agrr_bin).exists()
}

pub fn ensure_agrr_daemon_for_contract() {
    if !agrr_regeneration_contract_available() {
        return;
    }
    let agrr_bin =
        std::env::var("AGRR_BIN_PATH").unwrap_or_else(|_| "/app/lib/core/agrr".to_string());
    let _ = std::process::Command::new(&agrr_bin)
        .args(["daemon", "start"])
        .status();
    std::thread::sleep(std::time::Duration::from_secs(2));
}

pub fn poll_task_schedule_sync_ready(
    client: &ContractClient,
    session_id: &str,
    plan_id: i64,
) -> serde_json::Value {
    ensure_agrr_daemon_for_contract();
    let path = format!("/api/v1/plans/{plan_id}/task_schedule/regenerate");
    let (regen_status, regen_body) = status_and_body(
        client.post(&path, Some(session_id), &empty_headers(), None),
    );
    assert_eq!(200, regen_status, "{regen_body}");

    for _ in 0..120 {
        let (status, body) = status_and_body(client.get(
            &format!("/api/v1/plans/{plan_id}/task_schedule"),
            Some(session_id),
            &empty_headers(),
        ));
        assert_eq!(200, status, "{body}");
        let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
        let sync_state = json["plan"]["task_schedule_sync_state"]
            .as_str()
            .unwrap_or_default();
        if sync_state == "ready" {
            return json;
        }
        if sync_state == "failed" {
            panic!("task schedule regeneration failed: {body}");
        }
        std::thread::sleep(std::time::Duration::from_millis(250));
    }
    panic!("task schedule regeneration did not reach ready state within timeout");
}

/// Polls farm show until `weather_data_status` is `completed` (C3/C6 contract).
pub fn poll_farm_weather_completed(
    client: &ContractClient,
    session_id: &str,
    farm_id: i64,
) -> serde_json::Value {
    ensure_agrr_daemon_for_contract();
    let path = format!("/api/v1/masters/farms/{farm_id}");
    let mut last_progress = 0i64;
    for _ in 0..240 {
        let (status, body) = status_and_body(client.get(&path, Some(session_id), &empty_headers()));
        assert_eq!(200, status, "{body}");
        let json: serde_json::Value = serde_json::from_str(&body).expect("farm show JSON");
        let weather_status = json["weather_data_status"].as_str().unwrap_or_default();
        if weather_status == "completed" {
            assert_eq!(100, json["weather_data_progress"].as_i64().unwrap_or(0));
            return json;
        }
        if weather_status == "failed" {
            panic!("farm weather fetch failed: {body}");
        }
        if weather_status == "fetching" {
            let progress = json["weather_data_progress"].as_i64().unwrap_or(0);
            assert!(
                progress >= last_progress,
                "weather_data_progress should not decrease (was {last_progress}, now {progress})"
            );
            last_progress = progress;
        }
        std::thread::sleep(std::time::Duration::from_millis(500));
    }
    panic!("farm weather fetch did not reach completed within timeout");
}

fn schedule_item_ids(json: &serde_json::Value) -> Vec<i64> {
    json["fields"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .flat_map(|field| {
            field["schedules"]["general"]
                .as_array()
                .unwrap_or(&vec![])
                .iter()
                .filter_map(|item| item["id"].as_i64())
                .collect::<Vec<_>>()
        })
        .collect()
}

pub fn find_schedule_item<'a>(
    json: &'a serde_json::Value,
    item_id: i64,
) -> &'a serde_json::Value {
    json["fields"]
        .as_array()
        .expect("fields")
        .iter()
        .flat_map(|field| {
            field["schedules"]["general"]
                .as_array()
                .expect("general schedules")
                .iter()
        })
        .find(|item| item["id"].as_i64() == Some(item_id))
        .unwrap_or_else(|| panic!("schedule item {item_id} missing"))
}

pub fn schedule_item_ids_from_response(json: &serde_json::Value) -> Vec<i64> {
    schedule_item_ids(json)
}

/// Runs upload_init → content PUT → upload_complete for one JPEG photo.
pub fn upload_ready_work_record_photo(
    client: &ContractClient,
    session_id: &str,
    plan_id: i64,
    record_id: i64,
) {
    let init_path = format!(
        "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/upload_init"
    );
    let (init_status, init_body) = status_and_body(client.post(
        &init_path,
        Some(session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "photo": { "content_type": "image/jpeg" }
        })),
    ));
    assert_eq!(201, init_status, "{init_body}");
    let init_json: serde_json::Value =
        serde_json::from_str(&init_body).expect("upload_init JSON");
    let photo_id = init_json["photo"]["id"].as_i64().expect("photo id");
    let upload_url = init_json["photo"]["upload_url"]
        .as_str()
        .expect("upload_url");

    let jpeg_bytes: Vec<u8> = vec![0xFF, 0xD8, 0xFF, 0xD9];
    let (upload_status, upload_body) = status_and_body(client.put_bytes(
        upload_url,
        Some(session_id),
        &empty_headers(),
        "image/jpeg",
        &jpeg_bytes,
    ));
    assert_eq!(204, upload_status, "{upload_body}");

    let complete_path = format!(
        "/api/v1/plans/{plan_id}/work_records/{record_id}/photos/{photo_id}/upload_complete"
    );
    let (complete_status, complete_body) = status_and_body(client.post(
        &complete_path,
        Some(session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "photo": { "byte_size": jpeg_bytes.len() }
        })),
    ));
    assert_eq!(200, complete_status, "{complete_body}");
}

fn write_contract_observed_weather_gcs_fixture(weather_location_id: i64) {
    let local_root = std::env::var("WEATHER_DATA_LOCAL_ROOT")
        .unwrap_or_else(|_| "/tmp/agrr-weather-contract".to_string());
    let object_path = format!("{local_root}/weather_data/{weather_location_id}/2026.json");
    if let Some(parent) = std::path::Path::new(&object_path).parent() {
        std::fs::create_dir_all(parent).expect("create weather gcs mirror dir");
    }
    let payload = r#"{
      "2026-07-01": {"temperature_max": 21.0, "temperature_min": 8.0, "temperature_mean": 14.0},
      "2026-07-02": {"temperature_max": 21.0, "temperature_min": 8.0, "temperature_mean": 14.0},
      "2026-07-03": {"temperature_max": 21.0, "temperature_min": 8.0, "temperature_mean": 14.0},
      "2026-07-04": {"temperature_max": 21.0, "temperature_min": 8.0, "temperature_mean": 14.0},
      "2026-07-05": {"temperature_max": 21.0, "temperature_min": 8.0, "temperature_mean": 14.0}
    }"#;
    std::fs::write(&object_path, payload).expect("write observed weather gcs fixture");
}

pub struct FarmTemperatureChartSeed {
    pub farm_id: i64,
}

/// Seeds a private farm with completed weather data for temperature chart contract tests.
pub fn seed_farm_temperature_chart_completed(user_id: i64) -> FarmTemperatureChartSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let farm_name = format!("Contract Temp Chart Farm {suffix}");

    conn.execute(
        "INSERT INTO weather_locations (latitude, longitude, elevation, timezone, created_at, updated_at)
         VALUES (35.1, 139.2, 40.0, 'Asia/Tokyo', datetime('now'), datetime('now'))",
        [],
    )
    .expect("insert weather_location");
    let weather_location_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO farms (
           user_id, name, latitude, longitude, created_at, updated_at, is_reference,
           weather_data_status, weather_data_fetched_years, weather_data_total_years,
           weather_location_id
         ) VALUES (
           ?1, ?2, 35.0, 139.0, datetime('now'), datetime('now'), 0,
           'completed', 5, 5, ?3
         )",
        params![user_id, farm_name, weather_location_id],
    )
    .expect("insert farm");
    let farm_id = conn.last_insert_rowid();

    for day in 1..=5 {
        let date = format!("2026-07-{day:02}");
        conn.execute(
            "INSERT INTO weather_data (
               weather_location_id, date, temperature_max, temperature_min, temperature_mean,
               created_at, updated_at
             ) VALUES (?1, ?2, 21.0, 8.0, 14.0, datetime('now'), datetime('now'))",
            params![weather_location_id, date],
        )
        .expect("insert weather_data row");
    }

    write_contract_observed_weather_gcs_fixture(weather_location_id);

    FarmTemperatureChartSeed { farm_id }
}

/// Seeds a private farm with fetching weather status (chart should return 409).
pub fn seed_farm_temperature_chart_fetching(user_id: i64) -> i64 {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let farm_name = format!("Contract Temp Chart Fetching {suffix}");

    conn.execute(
        "INSERT INTO weather_locations (latitude, longitude, created_at, updated_at)
         VALUES (35.1, 139.2, datetime('now'), datetime('now'))",
        [],
    )
    .expect("insert weather_location");
    let weather_location_id = conn.last_insert_rowid();

    conn.execute(
        "INSERT INTO farms (
           user_id, name, latitude, longitude, created_at, updated_at, is_reference,
           weather_data_status, weather_data_fetched_years, weather_data_total_years,
           weather_location_id
         ) VALUES (
           ?1, ?2, 35.0, 139.0, datetime('now'), datetime('now'), 0,
           'fetching', 2, 5, ?3
         )",
        params![user_id, farm_name, weather_location_id],
    )
    .expect("insert farm");

    conn.last_insert_rowid()
}

/// Unique coordinates with pre-seeded GCS bulk metadata so farm-create weather fetch
/// completes via cache hits (no live agrr JMA fetch required in CI).
pub struct FarmCreateWeatherCacheSeed {
    pub latitude: f64,
    pub longitude: f64,
}

fn days_in_year(year: i32) -> u32 {
    if (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0) {
        366
    } else {
        365
    }
}

fn write_contract_weather_gcs_year(weather_location_id: i64, year: i32, payload: &str) {
    let local_root = std::env::var("WEATHER_DATA_LOCAL_ROOT")
        .unwrap_or_else(|_| "/tmp/agrr-weather-contract".to_string());
    let object_path = format!("{local_root}/weather_data/{weather_location_id}/{year}.json");
    if let Some(parent) = std::path::Path::new(&object_path).parent() {
        std::fs::create_dir_all(parent).expect("create weather gcs mirror dir");
    }
    std::fs::write(&object_path, payload).expect("write weather gcs year fixture");
}

pub fn seed_weather_cache_for_farm_create_completion() -> FarmCreateWeatherCacheSeed {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let seq = SEED_SEQ.fetch_add(1, Ordering::Relaxed);
    let latitude = 36.0 + (seq % 900) as f64 / 10_000.0;
    let longitude = 140.0 + (seq % 900) as f64 / 10_000.0;

    conn.execute(
        "INSERT INTO weather_locations (latitude, longitude, elevation, timezone, created_at, updated_at)
         VALUES (?1, ?2, 40.0, 'Asia/Tokyo', datetime('now'), datetime('now'))",
        params![latitude, longitude],
    )
    .expect("insert weather_location");
    let weather_location_id = conn.last_insert_rowid();

    let mut years = serde_json::Map::new();
    for year in 2000..=2026 {
        let day_count = if year == 2026 {
            205
        } else {
            days_in_year(year)
        };
        let last_date = if year == 2026 {
            "2026-07-24".to_string()
        } else {
            format!("{year}-12-31")
        };
        years.insert(
            year.to_string(),
            serde_json::json!({
                "count": day_count,
                "historical_count": day_count,
                "first_date": format!("{year}-01-01"),
                "last_date": last_date,
            }),
        );
    }
    let bulk_stats = serde_json::json!({
        "earliest_date": "2000-01-01",
        "latest_date": "2026-07-24",
        "years": years,
    });
    conn.execute(
        "UPDATE weather_locations
         SET bulk_earliest_date = '2000-01-01',
             bulk_latest_date = '2026-07-24',
             bulk_year_stats = ?1,
             updated_at = datetime('now')
         WHERE id = ?2",
        params![bulk_stats.to_string(), weather_location_id],
    )
    .expect("update weather location bulk metadata");

    let mut chart_days = serde_json::Map::new();
    for (month, start_day, end_day) in [(4, 26, 30), (5, 1, 31), (6, 1, 30), (7, 1, 24)] {
        for day in start_day..=end_day {
            let date = format!("2026-{month:02}-{day:02}");
            chart_days.insert(
                date,
                serde_json::json!({
                    "temperature_max": 21.0,
                    "temperature_min": 8.0,
                    "temperature_mean": 14.0,
                }),
            );
        }
    }
    write_contract_weather_gcs_year(
        weather_location_id,
        2026,
        &serde_json::to_string(&chart_days).expect("chart gcs json"),
    );

    eprintln!("seeded weather cache for farm create completion: {suffix} @ {latitude},{longitude}");
    FarmCreateWeatherCacheSeed {
        latitude,
        longitude,
    }
}

/// Seeds a user farm stuck at `pending` with coordinates (pre-#464 backfill scenario).
pub fn seed_farm_pending_weather(user_id: i64) -> i64 {
    let path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    let suffix = seed_suffix();
    let farm_name = format!("Contract Pending Weather Farm {suffix}");

    conn.execute(
        "INSERT INTO farms (
           user_id, name, latitude, longitude, created_at, updated_at, is_reference,
           weather_data_status, weather_data_fetched_years, weather_data_total_years,
           weather_location_id
         ) VALUES (
           ?1, ?2, 35.6895, 139.6917, datetime('now'), datetime('now'), 0,
           'pending', 0, 0, NULL
         )",
        params![user_id, farm_name],
    )
    .expect("insert pending farm");

    conn.last_insert_rowid()
}

pub fn scheduler_auth_headers() -> HashMap<String, String> {
    let token = std::env::var("SCHEDULER_AUTH_TOKEN")
        .unwrap_or_else(|_| "test_scheduler_token_contract".into());
    let mut headers = HashMap::new();
    headers.insert("X-Scheduler-Token".into(), token);
    headers
}

