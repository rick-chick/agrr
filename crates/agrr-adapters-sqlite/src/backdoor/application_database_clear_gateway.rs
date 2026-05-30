//! Ruby: `Adapters::Backdoor::Gateways::ApplicationDatabaseClearActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::backdoor::gateways::{
    ApplicationDataStats, ApplicationDatabaseClearGateway, ClearApplicationDataResult,
};
use rusqlite::Connection;

pub struct ApplicationDatabaseClearSqliteGateway {
    pool: SqlitePool,
}

impl ApplicationDatabaseClearSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl ApplicationDatabaseClearGateway for ApplicationDatabaseClearSqliteGateway {
    fn clear_application_data_preserving_anonymous_users(&self) -> ClearApplicationDataResult {
        match self.pool.with_write(|conn| {
            let before = snapshot_core_counts(conn)?;
            conn.execute_batch("BEGIN IMMEDIATE")?;
            delete_application_data(conn)?;
            let after = snapshot_core_counts(conn)?;
            conn.execute_batch("COMMIT")?;
            Ok(ClearApplicationDataResult::success(before, after))
        }) {
            Ok(result) => result,
            Err(e) => ClearApplicationDataResult::failure(format!(
                "Failed to clear database: {e}"
            )),
        }
    }
}

fn snapshot_core_counts(conn: &Connection) -> rusqlite::Result<ApplicationDataStats> {
    let users: i64 = conn.query_row(
        "SELECT COUNT(*) FROM users WHERE COALESCE(is_anonymous, 0) = 0",
        [],
        |row| row.get(0),
    )?;
    let farms: i64 = conn.query_row("SELECT COUNT(*) FROM farms", [], |row| row.get(0))?;
    let fields: i64 = conn.query_row("SELECT COUNT(*) FROM fields", [], |row| row.get(0))?;
    let crops: i64 = conn.query_row("SELECT COUNT(*) FROM crops", [], |row| row.get(0))?;
    let cultivation_plans: i64 = conn.query_row(
        "SELECT COUNT(*) FROM cultivation_plans",
        [],
        |row| row.get(0),
    )?;
    Ok(ApplicationDataStats {
        users,
        farms,
        fields,
        crops,
        cultivation_plans,
    })
}

/// Order mirrors Ruby `ApplicationDatabaseClearActiveRecordGateway`.
fn delete_application_data(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM sessions", [])?;
    conn.execute("DELETE FROM agricultural_tasks", [])?;
    conn.execute("DELETE FROM fertilizes", [])?;
    conn.execute("DELETE FROM pests", [])?;
    conn.execute("DELETE FROM pesticides", [])?;
    conn.execute("DELETE FROM interaction_rules", [])?;
    conn.execute("DELETE FROM cultivation_plans", [])?;
    conn.execute("DELETE FROM crops", [])?;
    conn.execute("DELETE FROM fields", [])?;
    conn.execute("DELETE FROM farms", [])?;
    conn.execute(
        "DELETE FROM users WHERE COALESCE(is_anonymous, 0) = 0",
        [],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::backdoor::gateways::ClearApplicationDataResult;
    use rusqlite::Connection;

    fn test_db_path(name: &str) -> String {
        let dir = std::env::temp_dir().join(format!("agrr_backdoor_clear_{name}"));
        let _ = std::fs::create_dir_all(&dir);
        dir.join("test.sqlite3").to_string_lossy().into_owned()
    }

    fn in_memory_schema(conn: &Connection) {
        conn.execute_batch(
            r#"
            PRAGMA foreign_keys = OFF;
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              email TEXT, name TEXT, google_id TEXT, avatar_url TEXT,
              admin INTEGER DEFAULT 0, is_anonymous INTEGER DEFAULT 0,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE farms (id INTEGER PRIMARY KEY, name TEXT, user_id INTEGER);
            CREATE TABLE fields (id INTEGER PRIMARY KEY, name TEXT, farm_id INTEGER);
            CREATE TABLE crops (id INTEGER PRIMARY KEY, name TEXT, user_id INTEGER);
            CREATE TABLE cultivation_plans (id INTEGER PRIMARY KEY, user_id INTEGER, farm_id INTEGER);
            CREATE TABLE interaction_rules (id INTEGER PRIMARY KEY);
            CREATE TABLE pesticides (id INTEGER PRIMARY KEY);
            CREATE TABLE pests (id INTEGER PRIMARY KEY);
            CREATE TABLE fertilizes (id INTEGER PRIMARY KEY);
            CREATE TABLE agricultural_tasks (id INTEGER PRIMARY KEY);
            CREATE TABLE sessions (id INTEGER PRIMARY KEY, user_id INTEGER);
        "#,
        )
        .unwrap();
    }

    fn seed(conn: &Connection) {
        conn.execute(
            "INSERT INTO users (email, name, google_id, is_anonymous) VALUES ('anon', 'Anon', 'a1', 1)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO users (email, name, google_id, is_anonymous) VALUES ('real@example.com', 'Real', 'r1', 0)",
            [],
        )
        .unwrap();
        conn.execute("INSERT INTO farms (name, user_id) VALUES ('F1', 2)", [])
            .unwrap();
        conn.execute("INSERT INTO fields (name, farm_id) VALUES ('Field', 1)", [])
            .unwrap();
        conn.execute("INSERT INTO crops (name, user_id) VALUES ('Crop', 2)", [])
            .unwrap();
        conn.execute(
            "INSERT INTO cultivation_plans (user_id, farm_id) VALUES (2, 1)",
            [],
        )
        .unwrap();
        conn.execute("INSERT INTO sessions (user_id) VALUES (2)", [])
            .unwrap();
    }

    #[test]
    fn clear_preserves_anonymous_users_and_zeros_core_counts() {
        let path = test_db_path("preserve_anon");
        let conn = Connection::open(&path).unwrap();
        in_memory_schema(&conn);
        seed(&conn);
        drop(conn);

        let gateway = ApplicationDatabaseClearSqliteGateway::new(SqlitePool::new(&path));
        let result = gateway.clear_application_data_preserving_anonymous_users();
        let ClearApplicationDataResult::Success {
            before_stats,
            after_stats,
        } = result
        else {
            panic!("expected success, got {result:?}");
        };

        assert_eq!(before_stats.users, 1);
        assert_eq!(before_stats.farms, 1);
        assert_eq!(before_stats.fields, 1);
        assert_eq!(before_stats.crops, 1);
        assert_eq!(before_stats.cultivation_plans, 1);

        assert_eq!(after_stats.users, 0);
        assert_eq!(after_stats.farms, 0);
        assert_eq!(after_stats.fields, 0);
        assert_eq!(after_stats.crops, 0);
        assert_eq!(after_stats.cultivation_plans, 0);

        let pool = SqlitePool::new(&path);
        let anon_count: i64 = pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT COUNT(*) FROM users WHERE is_anonymous = 1",
                    [],
                    |row| row.get(0),
                )
            })
            .unwrap();
        assert_eq!(anon_count, 1);
    }

    #[test]
    fn clear_returns_failure_when_table_missing() {
        let path = test_db_path("missing_table");
        let conn = Connection::open(&path).unwrap();
        conn.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY)")
            .unwrap();
        drop(conn);

        let gateway = ApplicationDatabaseClearSqliteGateway::new(SqlitePool::new(&path));
        let result = gateway.clear_application_data_preserving_anonymous_users();
        assert!(matches!(result, ClearApplicationDataResult::Failure { .. }));
    }
}
