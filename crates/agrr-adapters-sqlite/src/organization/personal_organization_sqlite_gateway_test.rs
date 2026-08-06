//! Integration tests for `PersonalOrganizationSqliteGateway`.

use super::PersonalOrganizationSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::organization::gateways::PersonalOrganizationGateway;

fn personal_org_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_personal_org_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "personal_org_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT,
              name TEXT,
              created_at TEXT,
              updated_at TEXT
            );
            CREATE TABLE organizations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              slug TEXT NOT NULL UNIQUE,
              is_personal INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE organization_memberships (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              organization_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              role TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(organization_id, user_id)
            );
            CREATE TABLE farms (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              organization_id INTEGER,
              created_at TEXT,
              updated_at TEXT
            );
            CREATE TABLE crops (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              name TEXT NOT NULL,
              is_reference INTEGER DEFAULT 0,
              organization_id INTEGER,
              created_at TEXT,
              updated_at TEXT
            );
            CREATE TABLE fields (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              farm_id INTEGER,
              name TEXT NOT NULL,
              organization_id INTEGER,
              created_at TEXT,
              updated_at TEXT
            );
            CREATE TABLE cultivation_plans (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);
            CREATE TABLE agricultural_tasks (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);
            CREATE TABLE fertilizes (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);
            CREATE TABLE interaction_rules (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);
            CREATE TABLE pests (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);
            CREATE TABLE pesticides (id INTEGER PRIMARY KEY, user_id INTEGER, organization_id INTEGER);",
        )
    })
    .unwrap();
    pool
}

fn seed_user(pool: &SqlitePool, email: &str, name: &str) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO users (email, name, created_at, updated_at) VALUES (?1, ?2, datetime('now'), datetime('now'))",
            rusqlite::params![email, name],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

#[test]
fn ensure_creates_personal_org_and_backfills_tier1() {
    let pool = personal_org_test_pool();
    let user_id = seed_user(&pool, "farmer@example.com", "Farmer");
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (user_id, name, created_at, updated_at) VALUES (?1, 'Farm', datetime('now'), datetime('now'))",
            rusqlite::params![user_id],
        )?;
        conn.execute(
            "INSERT INTO crops (user_id, name, is_reference, created_at, updated_at) VALUES (?1, 'Crop', 0, datetime('now'), datetime('now'))",
            rusqlite::params![user_id],
        )?;
        Ok(())
    })
    .unwrap();

    let gw = PersonalOrganizationSqliteGateway::new(pool.clone());
    let org_id = gw
        .ensure_personal_organization(user_id, "farmer@example.com", "Farmer")
        .unwrap();

    pool.with_read(|conn| {
        let slug: String = conn.query_row(
            "SELECT slug FROM organizations WHERE id = ?1",
            rusqlite::params![org_id],
            |row| row.get(0),
        )?;
        assert_eq!(format!("user-{user_id}"), slug);

        let role: String = conn.query_row(
            "SELECT role FROM organization_memberships WHERE organization_id = ?1 AND user_id = ?2",
            rusqlite::params![org_id, user_id],
            |row| row.get(0),
        )?;
        assert_eq!("owner", role);

        let farm_org: i64 = conn.query_row(
            "SELECT organization_id FROM farms WHERE user_id = ?1",
            rusqlite::params![user_id],
            |row| row.get(0),
        )?;
        assert_eq!(org_id, farm_org);

        let crop_org: i64 = conn.query_row(
            "SELECT organization_id FROM crops WHERE user_id = ?1",
            rusqlite::params![user_id],
            |row| row.get(0),
        )?;
        assert_eq!(org_id, crop_org);
        Ok(())
    })
    .unwrap();
}

#[test]
fn ensure_is_idempotent() {
    let pool = personal_org_test_pool();
    let user_id = seed_user(&pool, "", "No Email");
    let gw = PersonalOrganizationSqliteGateway::new(pool.clone());
    let first = gw
        .ensure_personal_organization(user_id, "", "No Email")
        .unwrap();
    let second = gw
        .ensure_personal_organization(user_id, "", "No Email")
        .unwrap();
    assert_eq!(first, second);

    let count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM organizations WHERE is_personal = 1",
                [],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(1, count);
}

#[test]
fn list_users_needing_personal_organization_excludes_complete_users() {
    let pool = personal_org_test_pool();
    let user_a = seed_user(&pool, "a@example.com", "A");
    let user_b = seed_user(&pool, "b@example.com", "B");
    let gw = PersonalOrganizationSqliteGateway::new(pool.clone());
    gw.ensure_personal_organization(user_a, "a@example.com", "A")
        .unwrap();

    let needing = gw.list_users_needing_personal_organization().unwrap();
    assert_eq!(vec![user_b], needing.iter().map(|r| r.user_id).collect::<Vec<_>>());
}

#[test]
fn backfill_fields_via_farm_when_user_id_null() {
    let pool = personal_org_test_pool();
    let user_id = seed_user(&pool, "f@example.com", "F");
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (user_id, name, created_at, updated_at) VALUES (?1, 'Farm', datetime('now'), datetime('now'))",
            rusqlite::params![user_id],
        )?;
        let farm_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO fields (farm_id, name, created_at, updated_at) VALUES (?1, 'Field', datetime('now'), datetime('now'))",
            rusqlite::params![farm_id],
        )?;
        Ok(())
    })
    .unwrap();

    let gw = PersonalOrganizationSqliteGateway::new(pool.clone());
    let org_id = gw
        .ensure_personal_organization(user_id, "f@example.com", "F")
        .unwrap();

    let field_org: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT organization_id FROM fields LIMIT 1",
                [],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(org_id, field_org);
}
