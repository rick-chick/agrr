//! Ruby: `Adapters::Backdoor::Gateways::BackdoorDiagnosticsActiveRecordGateway`

use crate::pool::SqlitePool;
use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BackdoorUserSummary {
    pub id: i64,
    pub email: Option<String>,
    pub name: Option<String>,
    pub google_id: Option<String>,
    pub admin: bool,
    pub avatar_url: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub farms_count: i64,
    pub plans_count: i64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BackdoorUserDetail {
    pub id: i64,
    pub email: Option<String>,
    pub name: Option<String>,
    pub google_id: Option<String>,
    pub admin: bool,
    pub avatar_url: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BackdoorUsersListPayload {
    pub total_users: i64,
    pub users: Vec<BackdoorUserSummary>,
}

#[derive(Debug, Clone, Default)]
pub struct BackdoorCreateUserAttrs {
    pub email: Option<String>,
    pub name: Option<String>,
    pub google_id: Option<String>,
    pub avatar_url: Option<String>,
    pub admin: bool,
}

#[derive(Debug, Clone, Default)]
pub struct BackdoorUpdateUserAttrs {
    pub email: Option<String>,
    pub name: Option<String>,
    pub google_id: Option<String>,
    pub avatar_url: Option<String>,
    pub admin: Option<bool>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum BackdoorCreateUserResult {
    Ok { user: BackdoorUserDetail },
    Invalid { errors: Vec<String> },
}

#[derive(Debug, Clone, PartialEq)]
pub enum BackdoorUpdateUserResult {
    Ok { user: BackdoorUserDetail },
    NotFound,
    Invalid { errors: Vec<String> },
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BackdoorDbStatsCounts {
    pub users: i64,
    pub anonymous_users: i64,
    pub farms: i64,
    pub fields: i64,
    pub crops: i64,
    pub cultivation_plans: i64,
    pub interaction_rules: i64,
    pub pesticides: i64,
    pub pests: i64,
    pub fertilizes: i64,
    pub agricultural_tasks: i64,
    pub sessions: i64,
}

pub struct BackdoorDiagnosticsSqliteGateway {
    pool: SqlitePool,
}

impl BackdoorDiagnosticsSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub fn users_list_payload(&self) -> Result<BackdoorUsersListPayload, rusqlite::Error> {
        self.pool.with_read(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, email, name, google_id, COALESCE(admin, 0), avatar_url, created_at, updated_at \
                 FROM users WHERE COALESCE(is_anonymous, 0) = 0 ORDER BY created_at DESC",
            )?;
            let users: Vec<BackdoorUserSummary> = stmt
                .query_map([], |row| {
                    let id: i64 = row.get(0)?;
                    let admin: i64 = row.get(4)?;
                    let farms_count: i64 = conn
                        .query_row(
                            "SELECT COUNT(*) FROM farms WHERE user_id = ?1",
                            params![id],
                            |r| r.get(0),
                        )
                        .unwrap_or(0);
                    let plans_count: i64 = conn
                        .query_row(
                            "SELECT COUNT(*) FROM cultivation_plans WHERE user_id = ?1",
                            params![id],
                            |r| r.get(0),
                        )
                        .unwrap_or(0);
                    Ok(BackdoorUserSummary {
                        id,
                        email: row.get(1)?,
                        name: row.get(2)?,
                        google_id: row.get(3)?,
                        admin: admin != 0,
                        avatar_url: row.get(5)?,
                        created_at: row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                        updated_at: row.get::<_, Option<String>>(7)?.unwrap_or_default(),
                        farms_count,
                        plans_count,
                    })
                })?
                .collect::<Result<Vec<_>, _>>()?;
            let total_users = users.len() as i64;
            Ok(BackdoorUsersListPayload {
                total_users,
                users,
            })
        })
    }

    pub fn create_user(
        &self,
        attrs: BackdoorCreateUserAttrs,
    ) -> Result<BackdoorCreateUserResult, rusqlite::Error> {
        let email = attrs.email.unwrap_or_default();
        let name = attrs.name.unwrap_or_default();
        if email.is_empty() || name.is_empty() {
            return Ok(BackdoorCreateUserResult::Invalid {
                errors: vec!["Email can't be blank".into(), "Name can't be blank".into()],
            });
        }
        self.pool.with_write(|conn| {
            if let Err(e) = conn.execute(
                "INSERT INTO users (email, name, google_id, avatar_url, admin, is_anonymous, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, 0, datetime('now'), datetime('now'))",
                params![
                    email.to_lowercase(),
                    name,
                    attrs.google_id,
                    attrs.avatar_url,
                    if attrs.admin { 1 } else { 0 },
                ],
            ) {
                return Ok(BackdoorCreateUserResult::Invalid {
                    errors: vec![e.to_string()],
                });
            }
            let id = conn.last_insert_rowid();
            fetch_user_detail(conn, id).map(|user| BackdoorCreateUserResult::Ok { user })
        })
    }

    pub fn update_user(
        &self,
        id: i64,
        attrs: BackdoorUpdateUserAttrs,
    ) -> Result<BackdoorUpdateUserResult, rusqlite::Error> {
        self.pool.with_write(|conn| {
            let exists: bool = conn
                .query_row(
                    "SELECT 1 FROM users WHERE id = ?1 LIMIT 1",
                    params![id],
                    |_| Ok(true),
                )
                .optional()?
                .unwrap_or(false);
            if !exists {
                return Ok(BackdoorUpdateUserResult::NotFound);
            }

            let mut sets = Vec::new();
            let mut values: Vec<rusqlite::types::Value> = Vec::new();
            if let Some(email) = attrs.email {
                sets.push("email = ?");
                values.push(email.to_lowercase().into());
            }
            if let Some(name) = attrs.name {
                sets.push("name = ?");
                values.push(name.into());
            }
            if let Some(google_id) = attrs.google_id {
                sets.push("google_id = ?");
                values.push(google_id.into());
            }
            if let Some(avatar_url) = attrs.avatar_url {
                sets.push("avatar_url = ?");
                values.push(avatar_url.into());
            }
            if let Some(admin) = attrs.admin {
                sets.push("admin = ?");
                values.push((if admin { 1 } else { 0 }).into());
            }
            if sets.is_empty() {
                return fetch_user_detail(conn, id).map(|user| BackdoorUpdateUserResult::Ok { user });
            }
            sets.push("updated_at = datetime('now')");
            let sql = format!("UPDATE users SET {} WHERE id = ?", sets.join(", "));
            values.push(id.into());
            let params: Vec<&dyn rusqlite::ToSql> =
                values.iter().map(|v| v as &dyn rusqlite::ToSql).collect();
            if let Err(e) = conn.execute(&sql, params.as_slice()) {
                return Ok(BackdoorUpdateUserResult::Invalid {
                    errors: vec![e.to_string()],
                });
            }
            fetch_user_detail(conn, id).map(|user| BackdoorUpdateUserResult::Ok { user })
        })
    }

    pub fn db_stats_counts(&self) -> Result<BackdoorDbStatsCounts, rusqlite::Error> {
        self.pool.with_read(|conn| Ok(count_table_stats(conn)))
    }
}

fn count_table_stats(conn: &Connection) -> BackdoorDbStatsCounts {
    let count = |sql: &str| -> i64 {
        conn.query_row(sql, [], |row| row.get(0))
            .unwrap_or(0)
    };
    BackdoorDbStatsCounts {
        users: count("SELECT COUNT(*) FROM users WHERE COALESCE(is_anonymous, 0) = 0"),
        anonymous_users: count("SELECT COUNT(*) FROM users WHERE is_anonymous = 1"),
        farms: count("SELECT COUNT(*) FROM farms"),
        fields: count("SELECT COUNT(*) FROM fields"),
        crops: count("SELECT COUNT(*) FROM crops"),
        cultivation_plans: count("SELECT COUNT(*) FROM cultivation_plans"),
        interaction_rules: count("SELECT COUNT(*) FROM interaction_rules"),
        pesticides: count("SELECT COUNT(*) FROM pesticides"),
        pests: count("SELECT COUNT(*) FROM pests"),
        fertilizes: count("SELECT COUNT(*) FROM fertilizes"),
        agricultural_tasks: count("SELECT COUNT(*) FROM agricultural_tasks"),
        sessions: count("SELECT COUNT(*) FROM sessions"),
    }
}

fn fetch_user_detail(conn: &Connection, id: i64) -> Result<BackdoorUserDetail, rusqlite::Error> {
    conn.query_row(
        "SELECT id, email, name, google_id, COALESCE(admin, 0), avatar_url, created_at, updated_at \
         FROM users WHERE id = ?1",
        params![id],
        |row| {
            let admin: i64 = row.get(4)?;
            Ok(BackdoorUserDetail {
                id: row.get(0)?,
                email: row.get(1)?,
                name: row.get(2)?,
                google_id: row.get(3)?,
                admin: admin != 0,
                avatar_url: row.get(5)?,
                created_at: row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                updated_at: row.get::<_, Option<String>>(7)?.unwrap_or_default(),
            })
        },
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_db_path(name: &str) -> String {
        let dir = std::env::temp_dir().join(format!("agrr_backdoor_diag_{name}"));
        let _ = std::fs::create_dir_all(&dir);
        dir.join("test.sqlite3").to_string_lossy().into_owned()
    }

    fn schema(conn: &Connection) {
        conn.execute_batch(
            r#"
            PRAGMA foreign_keys = OFF;
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              email TEXT, name TEXT, google_id TEXT UNIQUE, avatar_url TEXT,
              admin INTEGER DEFAULT 0, is_anonymous INTEGER DEFAULT 0,
              created_at TEXT DEFAULT (datetime('now')),
              updated_at TEXT DEFAULT (datetime('now'))
            );
            CREATE TABLE farms (id INTEGER PRIMARY KEY, user_id INTEGER);
            CREATE TABLE fields (id INTEGER PRIMARY KEY);
            CREATE TABLE crops (id INTEGER PRIMARY KEY);
            CREATE TABLE cultivation_plans (id INTEGER PRIMARY KEY, user_id INTEGER);
            CREATE TABLE interaction_rules (id INTEGER PRIMARY KEY);
            CREATE TABLE pesticides (id INTEGER PRIMARY KEY);
            CREATE TABLE pests (id INTEGER PRIMARY KEY);
            CREATE TABLE fertilizes (id INTEGER PRIMARY KEY);
            CREATE TABLE agricultural_tasks (id INTEGER PRIMARY KEY);
            CREATE TABLE sessions (id INTEGER PRIMARY KEY);
        "#,
        )
        .unwrap();
    }

    #[test]
    fn users_list_excludes_anonymous() {
        let path = test_db_path("users_list");
        let conn = Connection::open(&path).unwrap();
        schema(&conn);
        conn.execute(
            "INSERT INTO users (email, name, google_id, is_anonymous) VALUES ('a@x.com', 'A', 'g1', 1)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO users (email, name, google_id, is_anonymous) VALUES ('u@x.com', 'U', 'g2', 0)",
            [],
        )
        .unwrap();
        drop(conn);

        let gw = BackdoorDiagnosticsSqliteGateway::new(SqlitePool::new(&path));
        let payload = gw.users_list_payload().unwrap();
        assert_eq!(payload.total_users, 1);
        assert_eq!(payload.users[0].email.as_deref(), Some("u@x.com"));
    }

    #[test]
    fn create_and_update_user() {
        let path = test_db_path("crud");
        let conn = Connection::open(&path).unwrap();
        schema(&conn);
        drop(conn);

        let gw = BackdoorDiagnosticsSqliteGateway::new(SqlitePool::new(&path));
        let created = gw
            .create_user(BackdoorCreateUserAttrs {
                email: Some("new@example.com".into()),
                name: Some("New".into()),
                google_id: Some("gid".into()),
                admin: true,
                ..Default::default()
            })
            .unwrap();
        let BackdoorCreateUserResult::Ok { user } = created else {
            panic!("create failed: {created:?}");
        };
        assert_eq!(user.email.as_deref(), Some("new@example.com"));
        assert!(user.admin);

        let updated = gw
            .update_user(
                user.id,
                BackdoorUpdateUserAttrs {
                    name: Some("Renamed".into()),
                    ..Default::default()
                },
            )
            .unwrap();
        let BackdoorUpdateUserResult::Ok { user: u2 } = updated else {
            panic!("update failed: {updated:?}");
        };
        assert_eq!(u2.name.as_deref(), Some("Renamed"));
    }

    #[test]
    fn db_stats_counts_reflect_tables() {
        let path = test_db_path("stats");
        let conn = Connection::open(&path).unwrap();
        schema(&conn);
        conn.execute(
            "INSERT INTO users (email, name, is_anonymous) VALUES ('u@x.com', 'U', 0)",
            [],
        )
        .unwrap();
        conn.execute("INSERT INTO farms DEFAULT VALUES", []).unwrap();
        drop(conn);

        let gw = BackdoorDiagnosticsSqliteGateway::new(SqlitePool::new(&path));
        let stats = gw.db_stats_counts().unwrap();
        assert_eq!(stats.users, 1);
        assert_eq!(stats.farms, 1);
        assert_eq!(stats.anonymous_users, 0);
    }
}
