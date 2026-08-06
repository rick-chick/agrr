//! Ruby: `Adapters::UserAccount::Gateways::UserAccountSqliteGateway`

use crate::pool::SqlitePool;
use agrr_domain::user_account::dtos::{UserDataExport, UserExportSnapshot};
use agrr_domain::user_account::gateways::UserAccountGateway;
use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Map, Value};

pub struct UserAccountSqliteGateway {
    pool: SqlitePool,
}

impl UserAccountSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl UserAccountGateway for UserAccountSqliteGateway {
    fn export_data(
        &self,
        user_id: i64,
    ) -> Result<UserDataExport, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let user = read_user_snapshot(conn, user_id)?;
            let farms = query_json_rows(
                conn,
                "SELECT id, name, latitude, longitude, is_reference, region, created_at, updated_at \
                 FROM farms WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
                params![user_id],
            )?;
            let crops = query_json_rows(
                conn,
                "SELECT id, name, variety, is_reference, region, area_per_unit, revenue_per_area, created_at, updated_at \
                 FROM crops WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
                params![user_id],
            )?;
            let cultivation_plans = query_json_rows(
                conn,
                "SELECT id, farm_id, plan_name, plan_year, plan_type, status, total_area, \
                 planning_start_date, planning_end_date, created_at, updated_at \
                 FROM cultivation_plans WHERE user_id = ?1",
                params![user_id],
            )?;
            Ok(UserDataExport {
                exported_at: String::new(),
                user,
                farms,
                crops,
                cultivation_plans,
            })
        })
    }

    fn list_photo_storage_keys(
        &self,
        user_id: i64,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT wrp.storage_key FROM work_record_photos wrp \
                 INNER JOIN cultivation_plans cp ON cp.id = wrp.cultivation_plan_id \
                 WHERE cp.user_id = ?1",
            )?;
            let keys = stmt
                .query_map(params![user_id], |row| row.get(0))?
                .filter_map(|r| r.ok())
                .collect();
            Ok(keys)
        })
    }

    fn delete_account(
        &self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute_batch("BEGIN IMMEDIATE")?;
            let result = delete_user_account_data(conn, user_id);
            if result.is_ok() {
                conn.execute_batch("COMMIT")?;
            } else {
                let _ = conn.execute_batch("ROLLBACK");
            }
            result
        })
    }

    fn user_email(
        &self,
        user_id: i64,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT email FROM users WHERE id = ?1 LIMIT 1",
                params![user_id],
                |row| row.get(0),
            )
            .optional()
            .map_err(Into::into)
        })
    }
}

fn read_user_snapshot(
    conn: &Connection,
    user_id: i64,
) -> Result<UserExportSnapshot, rusqlite::Error> {
    conn.query_row(
        "SELECT id, email, name, created_at FROM users WHERE id = ?1 LIMIT 1",
        params![user_id],
        |row| {
            Ok(UserExportSnapshot {
                id: row.get(0)?,
                email: row.get(1)?,
                name: row.get(2)?,
                created_at: row.get(3)?,
            })
        },
    )
}

fn query_json_rows(
    conn: &Connection,
    sql: &str,
    bind: impl rusqlite::Params,
) -> Result<Vec<Value>, rusqlite::Error> {
    let mut stmt = conn.prepare(sql)?;
    let column_names: Vec<String> = stmt
        .column_names()
        .iter()
        .map(|s| (*s).to_string())
        .collect();
    let mut rows = stmt.query(bind)?;
    let mut out = Vec::new();
    while let Some(row) = rows.next()? {
        let mut map = Map::new();
        for (i, name) in column_names.iter().enumerate() {
            let value: rusqlite::types::Value = row.get(i)?;
            map.insert(name.clone(), sqlite_value_to_json(value));
        }
        out.push(Value::Object(map));
    }
    Ok(out)
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

fn delete_user_account_data(conn: &Connection, user_id: i64) -> Result<(), rusqlite::Error> {
    let exists: i64 = conn.query_row(
        "SELECT COUNT(*) FROM users WHERE id = ?1 AND COALESCE(is_anonymous, 0) = 0",
        params![user_id],
        |row| row.get(0),
    )?;
    if exists == 0 {
        return Err(rusqlite::Error::QueryReturnedNoRows);
    }

    let plan_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM cultivation_plans WHERE user_id = ?1",
        params![user_id],
    )?;
    for plan_id in plan_ids {
        delete_cultivation_plan_graph(conn, plan_id)?;
    }

    let farm_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM farms WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    for farm_id in farm_ids {
        conn.execute(
            "DELETE FROM free_crop_plans WHERE farm_id = ?1",
            params![farm_id],
        )?;
        conn.execute("DELETE FROM fields WHERE farm_id = ?1", params![farm_id])?;
        conn.execute(
            "DELETE FROM farms WHERE id = ?1 AND user_id = ?2",
            params![farm_id, user_id],
        )?;
    }

    delete_user_pesticides(conn, user_id)?;
    delete_user_pests(conn, user_id)?;

    let crop_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM crops WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    for crop_id in crop_ids {
        delete_crop_graph(conn, crop_id)?;
    }

    conn.execute(
        "DELETE FROM agricultural_tasks WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    conn.execute(
        "DELETE FROM fertilizes WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    conn.execute(
        "DELETE FROM interaction_rules WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    conn.execute(
        "DELETE FROM deletion_undo_events WHERE deleted_by_id = ?1",
        params![user_id],
    )?;

    let personal_org_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT o.id FROM organizations o \
         INNER JOIN organization_memberships om ON om.organization_id = o.id \
         WHERE om.user_id = ?1 AND COALESCE(o.is_personal, 0) = 1",
        params![user_id],
    )?;
    conn.execute(
        "DELETE FROM organization_memberships WHERE user_id = ?1",
        params![user_id],
    )?;
    for org_id in personal_org_ids {
        conn.execute("DELETE FROM organizations WHERE id = ?1", params![org_id])?;
    }

    conn.execute("DELETE FROM sessions WHERE user_id = ?1", params![user_id])?;
    conn.execute("DELETE FROM users WHERE id = ?1", params![user_id])?;
    Ok(())
}

fn collect_ids(
    conn: &Connection,
    sql: &str,
    bind: impl rusqlite::Params,
) -> Result<Vec<i64>, rusqlite::Error> {
    let mut stmt = conn.prepare(sql)?;
    let rows = stmt.query_map(bind, |row| row.get(0))?;
    Ok(rows.filter_map(|r| r.ok()).collect())
}

fn delete_cultivation_plan_graph(conn: &Connection, plan_id: i64) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM work_record_photos WHERE cultivation_plan_id = ?1",
        params![plan_id],
    )?;
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
    conn.execute("DELETE FROM cultivation_plans WHERE id = ?1", params![plan_id])?;
    Ok(())
}

fn delete_user_pesticides(conn: &Connection, user_id: i64) -> rusqlite::Result<()> {
    let pesticide_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM pesticides WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    for pesticide_id in pesticide_ids {
        conn.execute(
            "DELETE FROM pesticide_application_details WHERE pesticide_id = ?1",
            params![pesticide_id],
        )?;
        conn.execute(
            "DELETE FROM pesticide_usage_constraints WHERE pesticide_id = ?1",
            params![pesticide_id],
        )?;
        conn.execute("DELETE FROM pesticides WHERE id = ?1", params![pesticide_id])?;
    }
    Ok(())
}

fn delete_user_pests(conn: &Connection, user_id: i64) -> rusqlite::Result<()> {
    let pest_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM pests WHERE user_id = ?1 AND COALESCE(is_reference, 0) = 0",
        params![user_id],
    )?;
    for pest_id in pest_ids {
        conn.execute(
            "DELETE FROM pest_control_methods WHERE pest_id = ?1",
            params![pest_id],
        )?;
        conn.execute(
            "DELETE FROM pest_temperature_profiles WHERE pest_id = ?1",
            params![pest_id],
        )?;
        conn.execute(
            "DELETE FROM pest_thermal_requirements WHERE pest_id = ?1",
            params![pest_id],
        )?;
        conn.execute("DELETE FROM crop_pests WHERE pest_id = ?1", params![pest_id])?;
        conn.execute("DELETE FROM pests WHERE id = ?1", params![pest_id])?;
    }
    Ok(())
}

fn delete_crop_graph(conn: &Connection, crop_id: i64) -> rusqlite::Result<()> {
    let stage_ids: Vec<i64> = collect_ids(
        conn,
        "SELECT id FROM crop_stages WHERE crop_id = ?1",
        params![crop_id],
    )?;
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
    conn.execute("DELETE FROM crops WHERE id = ?1", params![crop_id])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn test_db_path(name: &str) -> String {
        let dir = std::env::temp_dir().join(format!("agrr_user_account_{name}_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join("test.sqlite3").to_string_lossy().into_owned();
        let _ = std::fs::remove_file(&path);
        path
    }

    fn in_memory_schema(conn: &Connection) {
        conn.execute_batch(
            r#"
            PRAGMA foreign_keys = OFF;
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY, email TEXT, name TEXT, google_id TEXT,
              admin INTEGER DEFAULT 0, is_anonymous INTEGER DEFAULT 0,
              api_key TEXT, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS farms (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT,
              latitude REAL, longitude REAL, is_reference INTEGER DEFAULT 0,
              region TEXT, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS fields (id INTEGER PRIMARY KEY, farm_id INTEGER, name TEXT);
            CREATE TABLE IF NOT EXISTS crops (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT, variety TEXT,
              is_reference INTEGER DEFAULT 0, region TEXT,
              area_per_unit REAL, revenue_per_area REAL,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS crop_stages (id INTEGER PRIMARY KEY, crop_id INTEGER);
            CREATE TABLE IF NOT EXISTS cultivation_plans (
              id INTEGER PRIMARY KEY, user_id INTEGER, farm_id INTEGER,
              plan_name TEXT, plan_year INTEGER, plan_type TEXT DEFAULT 'private',
              status TEXT, total_area REAL,
              planning_start_date TEXT, planning_end_date TEXT,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS cultivation_plan_fields (id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER);
            CREATE TABLE IF NOT EXISTS cultivation_plan_crops (id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER);
            CREATE TABLE IF NOT EXISTS field_cultivations (id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER);
            CREATE TABLE IF NOT EXISTS task_schedules (id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER);
            CREATE TABLE IF NOT EXISTS task_schedule_items (id INTEGER PRIMARY KEY, task_schedule_id INTEGER);
            CREATE TABLE IF NOT EXISTS work_records (id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER);
            CREATE TABLE IF NOT EXISTS work_record_photos (
              id INTEGER PRIMARY KEY, work_record_id INTEGER, cultivation_plan_id INTEGER,
              storage_key TEXT
            );
            CREATE TABLE IF NOT EXISTS crop_pests (id INTEGER PRIMARY KEY, crop_id INTEGER, pest_id INTEGER);
            CREATE TABLE IF NOT EXISTS crop_task_schedule_blueprints (id INTEGER PRIMARY KEY, crop_id INTEGER);
            CREATE TABLE IF NOT EXISTS temperature_requirements (id INTEGER PRIMARY KEY, crop_stage_id INTEGER);
            CREATE TABLE IF NOT EXISTS thermal_requirements (id INTEGER PRIMARY KEY, crop_stage_id INTEGER);
            CREATE TABLE IF NOT EXISTS sunshine_requirements (id INTEGER PRIMARY KEY, crop_stage_id INTEGER);
            CREATE TABLE IF NOT EXISTS nutrient_requirements (id INTEGER PRIMARY KEY, crop_stage_id INTEGER);
            CREATE TABLE IF NOT EXISTS pests (id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS pest_control_methods (id INTEGER PRIMARY KEY, pest_id INTEGER);
            CREATE TABLE IF NOT EXISTS pest_temperature_profiles (id INTEGER PRIMARY KEY, pest_id INTEGER);
            CREATE TABLE IF NOT EXISTS pest_thermal_requirements (id INTEGER PRIMARY KEY, pest_id INTEGER);
            CREATE TABLE IF NOT EXISTS pesticides (id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS pesticide_application_details (id INTEGER PRIMARY KEY, pesticide_id INTEGER);
            CREATE TABLE IF NOT EXISTS pesticide_usage_constraints (id INTEGER PRIMARY KEY, pesticide_id INTEGER);
            CREATE TABLE IF NOT EXISTS free_crop_plans (id INTEGER PRIMARY KEY, farm_id INTEGER);
            CREATE TABLE IF NOT EXISTS agricultural_tasks (id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS fertilizes (id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS interaction_rules (id INTEGER PRIMARY KEY, user_id INTEGER, is_reference INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS deletion_undo_events (id TEXT PRIMARY KEY, deleted_by_id INTEGER);
            CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY, user_id INTEGER, session_id TEXT);
            CREATE TABLE IF NOT EXISTS organizations (
              id INTEGER PRIMARY KEY, name TEXT, slug TEXT, is_personal INTEGER DEFAULT 0,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS organization_memberships (
              id INTEGER PRIMARY KEY, organization_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
              role TEXT NOT NULL, created_at TEXT, updated_at TEXT,
              FOREIGN KEY (organization_id) REFERENCES organizations (id),
              FOREIGN KEY (user_id) REFERENCES users (id)
            );
            PRAGMA foreign_keys = ON;
        "#,
        )
        .unwrap();
    }

    fn seed(conn: &Connection) -> i64 {
        conn.execute(
            "INSERT INTO users (email, name, is_anonymous, created_at) VALUES ('u@example.com', 'User', 0, '2026-01-01')",
            [],
        )
        .unwrap();
        let user_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO farms (user_id, name, is_reference, created_at) VALUES (?1, 'Farm', 0, '2026-01-01')",
            params![user_id],
        )
        .unwrap();
        let farm_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO fields (farm_id, name) VALUES (?1, 'Field')",
            params![farm_id],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO crops (user_id, name, is_reference, created_at) VALUES (?1, 'Crop', 0, '2026-01-01')",
            params![user_id],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO cultivation_plans (user_id, farm_id, plan_name, status, total_area, created_at) \
             VALUES (?1, ?2, 'Plan', 'completed', 100.0, '2026-01-01')",
            params![user_id, farm_id],
        )
        .unwrap();
        let plan_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO work_records (cultivation_plan_id) VALUES (?1)",
            params![plan_id],
        )
        .unwrap();
        let record_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO work_record_photos (work_record_id, cultivation_plan_id, storage_key) \
             VALUES (?1, ?2, 'work_record_photos/1/1/photo.jpg')",
            params![record_id, plan_id],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO sessions (user_id, session_id) VALUES (?1, 'sess-1')",
            params![user_id],
        )
        .unwrap();
        user_id
    }

    #[test]
    fn export_data_returns_user_farms_crops_and_plans() {
        let path = test_db_path("export");
        let conn = Connection::open(&path).unwrap();
        in_memory_schema(&conn);
        let user_id = seed(&conn);
        drop(conn);

        let gateway = UserAccountSqliteGateway::new(SqlitePool::new(&path));
        let export = gateway.export_data(user_id).unwrap();
        assert_eq!(export.user.email.as_deref(), Some("u@example.com"));
        assert_eq!(export.farms.len(), 1);
        assert_eq!(export.crops.len(), 1);
        assert_eq!(export.cultivation_plans.len(), 1);
    }

    #[test]
    fn list_photo_storage_keys_returns_keys_for_user_plans() {
        let path = test_db_path("photo_keys");
        let conn = Connection::open(&path).unwrap();
        in_memory_schema(&conn);
        let user_id = seed(&conn);
        drop(conn);

        let gateway = UserAccountSqliteGateway::new(SqlitePool::new(&path));
        let keys = gateway.list_photo_storage_keys(user_id).unwrap();
        assert_eq!(keys, vec!["work_record_photos/1/1/photo.jpg".to_string()]);
    }

    fn seed_personal_organization(conn: &Connection, user_id: i64) -> i64 {
        conn.execute(
            "INSERT INTO organizations (name, slug, is_personal, created_at, updated_at) \
             VALUES ('Personal', 'personal-user', 1, '2026-01-01', '2026-01-01')",
            [],
        )
        .unwrap();
        let org_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, created_at, updated_at) \
             VALUES (?1, ?2, 'owner', '2026-01-01', '2026-01-01')",
            params![org_id, user_id],
        )
        .unwrap();
        org_id
    }

    #[test]
    fn delete_account_removes_user_data_and_sessions() {
        let path = test_db_path("delete");
        let conn = Connection::open(&path).unwrap();
        in_memory_schema(&conn);
        let user_id = seed(&conn);
        drop(conn);

        let gateway = UserAccountSqliteGateway::new(SqlitePool::new(&path));
        gateway.delete_account(user_id).unwrap();

        let pool = SqlitePool::new(&path);
        let user_count: i64 = pool
            .with_read(|c| c.query_row("SELECT COUNT(*) FROM users WHERE id = ?1", params![user_id], |r| r.get(0)))
            .unwrap();
        assert_eq!(user_count, 0);
        let farm_count: i64 = pool
            .with_read(|c| c.query_row("SELECT COUNT(*) FROM farms", [], |r| r.get(0)))
            .unwrap();
        assert_eq!(farm_count, 0);
        let session_count: i64 = pool
            .with_read(|c| c.query_row("SELECT COUNT(*) FROM sessions", [], |r| r.get(0)))
            .unwrap();
        assert_eq!(session_count, 0);
    }

    #[test]
    fn delete_account_removes_personal_organization() {
        let path = test_db_path("delete_personal_org");
        let conn = Connection::open(&path).unwrap();
        in_memory_schema(&conn);
        let user_id = seed(&conn);
        let org_id = seed_personal_organization(&conn, user_id);
        drop(conn);

        let gateway = UserAccountSqliteGateway::new(SqlitePool::new(&path));
        gateway.delete_account(user_id).unwrap();

        let pool = SqlitePool::new(&path);
        let org_count: i64 = pool
            .with_read(|c| c.query_row("SELECT COUNT(*) FROM organizations WHERE id = ?1", params![org_id], |r| r.get(0)))
            .unwrap();
        assert_eq!(org_count, 0);
        let membership_count: i64 = pool
            .with_read(|c| c.query_row("SELECT COUNT(*) FROM organization_memberships WHERE user_id = ?1", params![user_id], |r| r.get(0)))
            .unwrap();
        assert_eq!(membership_count, 0);
    }
}
