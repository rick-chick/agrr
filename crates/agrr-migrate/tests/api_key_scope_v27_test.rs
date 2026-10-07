mod support;

use agrr_migrate::schema;
use support::TestDb;

fn insert_scope_fixture(conn: &rusqlite::Connection, email: &str, scopes: Option<&str>) {
    conn.execute(
        "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin,
         api_key_hash, api_key, api_key_scopes, created_at, updated_at)
         VALUES (?1, ?2, NULL, NULL, 0, 0, ?3, ?4, ?5, datetime('now'), datetime('now'))",
        rusqlite::params![
            email,
            email,
            format!("hash-{}", email),
            if email.contains("plaintext") {
                Some(format!("plain-{}", email))
            } else {
                None::<String>
            },
            scopes,
        ],
    )
    .unwrap();
}

fn scope_for_email(conn: &rusqlite::Connection, email: &str) -> Option<String> {
    conn.query_row(
        "SELECT api_key_scopes FROM users WHERE email = ?1",
        [email],
        |row| row.get(0),
    )
    .unwrap()
}

fn updated_at_for_email(conn: &rusqlite::Connection, email: &str) -> String {
    conn.query_row(
        "SELECT updated_at FROM users WHERE email = ?1",
        [email],
        |row| row.get(0),
    )
    .unwrap()
}

fn reapply_v27_migration(db: &TestDb) {
    let conn = db.conn();
    let deleted = conn
        .execute("DELETE FROM refinery_schema_history WHERE version = 27", [])
        .unwrap();
    assert_eq!(1, deleted, "V27 must be recorded in refinery_schema_history before reapply");
    conn.close().unwrap();
    schema::run_primary(&db.paths.primary).expect("reapply V27");
}

#[test]
fn schema_run_v27_revokes_masters_write_scope_from_legacy_api_keys() {
    let db = TestDb::new();
    let conn = db.conn();

    insert_scope_fixture(
        &conn,
        "v27-a@fixture.dev",
        Some(r#"["masters:read","masters:write"]"#),
    );
    insert_scope_fixture(&conn, "v27-b@fixture.dev", Some(r#"["masters:read"]"#));
    insert_scope_fixture(&conn, "v27-c@fixture.dev", None);
    insert_scope_fixture(&conn, "v27-d@fixture.dev", Some(""));
    insert_scope_fixture(&conn, "v27-e@fixture.dev", Some(r#"["masters:write"]"#));
    insert_scope_fixture(
        &conn,
        "v27-f@fixture.dev",
        Some(r#"[ "masters:read" , "masters:write" ]"#),
    );
    insert_scope_fixture(
        &conn,
        "v27-plaintext@fixture.dev",
        Some(r#"["masters:read","masters:write"]"#),
    );

    let updated_before = updated_at_for_email(&conn, "v27-a@fixture.dev");
    conn.close().unwrap();

    reapply_v27_migration(&db);
    let conn = db.conn();

    assert_eq!(
        Some(r#"["masters:read"]"#.to_string()),
        scope_for_email(&conn, "v27-a@fixture.dev")
    );
    assert_eq!(
        Some(r#"["masters:read"]"#.to_string()),
        scope_for_email(&conn, "v27-b@fixture.dev")
    );
    assert_eq!(None, scope_for_email(&conn, "v27-c@fixture.dev"));
    assert_eq!(Some("".to_string()), scope_for_email(&conn, "v27-d@fixture.dev"));
    assert_eq!(
        Some(r#"["masters:read"]"#.to_string()),
        scope_for_email(&conn, "v27-e@fixture.dev")
    );
    assert_eq!(
        Some(r#"["masters:read"]"#.to_string()),
        scope_for_email(&conn, "v27-f@fixture.dev")
    );
    assert_eq!(
        Some(r#"["masters:read"]"#.to_string()),
        scope_for_email(&conn, "v27-plaintext@fixture.dev")
    );
    assert_eq!(
        updated_before,
        updated_at_for_email(&conn, "v27-a@fixture.dev"),
        "V27 must not touch updated_at"
    );
}

#[test]
fn schema_run_v27_is_idempotent() {
    let db = TestDb::new();
    let conn = db.conn();
    insert_scope_fixture(
        &conn,
        "v27-idem@fixture.dev",
        Some(r#"["masters:read","masters:write"]"#),
    );
    conn.close().unwrap();

    reapply_v27_migration(&db);
    let scopes_after_first = scope_for_email(&db.conn(), "v27-idem@fixture.dev");

    reapply_v27_migration(&db);
    let scopes_after_second = scope_for_email(&db.conn(), "v27-idem@fixture.dev");

    assert_eq!(Some(r#"["masters:read"]"#.to_string()), scopes_after_first);
    assert_eq!(scopes_after_first, scopes_after_second);
}
