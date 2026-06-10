use agrr_migrate::config::DbPaths;
use agrr_migrate::schema;
use rusqlite::Connection;
use tempfile::tempdir;

#[test]
fn embedded_primary_latest_version_includes_v3() {
    assert!(schema::embedded_primary_latest_version() >= 3_i64);
}

#[test]
fn schema_up_to_date_false_when_primary_stuck_at_v2() {
    let dir = tempdir().unwrap();
    let primary = dir.path().join("primary.sqlite3");
    let cache = dir.path().join("cache.sqlite3");
    let paths = DbPaths {
        app_root: std::env::current_dir()
            .unwrap()
            .ancestors()
            .find(|p| p.join("Cargo.toml").exists())
            .unwrap()
            .to_path_buf(),
        primary: primary.clone(),
        cache: cache.clone(),
    };

    let conn = Connection::open(&primary).unwrap();
    conn.execute_batch(
        "CREATE TABLE refinery_schema_history (
            version INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            applied_on TEXT NOT NULL,
            checksum TEXT NOT NULL
        );
        INSERT INTO refinery_schema_history (version, name, applied_on, checksum)
        VALUES (2, 'data_migration_history', '2020-01-01 00:00:00', 'test');",
    )
    .unwrap();

    let cache_conn = Connection::open(&cache).unwrap();
    cache_conn
        .execute_batch(
            "CREATE TABLE refinery_schema_history (
            version INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            applied_on TEXT NOT NULL,
            checksum TEXT NOT NULL
        );
        INSERT INTO refinery_schema_history (version, name, applied_on, checksum)
        VALUES (1, 'baseline', '2020-01-01 00:00:00', 'test');",
        )
        .unwrap();

    assert!(!schema::schema_up_to_date(&paths).unwrap());
}

#[test]
fn schema_run_on_empty_primary_and_cache() {
    let dir = tempdir().unwrap();
    let primary = dir.path().join("primary.sqlite3");
    let cache = dir.path().join("cache.sqlite3");
    let paths = DbPaths {
        app_root: std::env::current_dir()
            .unwrap()
            .ancestors()
            .find(|p| p.join("Cargo.toml").exists())
            .unwrap()
            .to_path_buf(),
        primary: primary.clone(),
        cache: cache.clone(),
    };
    schema::run(&paths).expect("schema run");
    schema::verify(&paths).expect("verify");
    assert!(schema::schema_up_to_date(&paths).unwrap());
}
