use agrr_migrate::config::DbPaths;
use agrr_migrate::schema;
use rusqlite::Connection;
use tempfile::tempdir;

#[test]
fn embedded_primary_latest_version_includes_v5() {
    assert!(schema::embedded_primary_latest_version() >= 5_i64);
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
fn schema_run_preserves_indexes_and_drops_predicted_weather_data() {
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

    let conn = Connection::open(&primary).unwrap();

    let expected_indexes = [
        "index_cultivation_plans_on_farm_user_unique",
        "index_cultivation_plans_on_user_id",
        "index_farms_on_user_id_and_name",
        "index_farms_on_user_id_and_source_farm_id",
        "index_farms_on_weather_location_id",
    ];
    for index_name in expected_indexes {
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = ?1",
                [index_name],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1, "index {index_name} should exist after schema run");
    }

    for table in ["cultivation_plans", "farms", "weather_locations"] {
        let mut stmt = conn
            .prepare(&format!("PRAGMA table_info({table})"))
            .unwrap();
        let columns: Vec<String> = stmt
            .query_map([], |row| row.get::<_, String>(1))
            .unwrap()
            .map(|r| r.unwrap())
            .collect();
        assert!(
            !columns.iter().any(|c| c == "predicted_weather_data"),
            "table {table} should not have predicted_weather_data column"
        );
    }

    let metadata_table_count: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'predicted_weather_metadata'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(
        metadata_table_count, 1,
        "predicted_weather_metadata table should exist"
    );
}

#[test]
fn schema_run_includes_v16_organizations_tables_and_tier1_organization_id() {
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

    let conn = Connection::open(&primary).unwrap();

    for table in ["organizations", "organization_memberships"] {
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?1",
                [table],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1, "table {table} should exist after schema run");
    }

    let tier1_tables = [
        "farms",
        "crops",
        "cultivation_plans",
        "fields",
        "agricultural_tasks",
        "fertilizes",
        "interaction_rules",
        "pests",
        "pesticides",
    ];
    for table in tier1_tables {
        let mut stmt = conn
            .prepare(&format!("PRAGMA table_info({table})"))
            .unwrap();
        let columns: Vec<(String, i64)> = stmt
            .query_map([], |row| Ok((row.get::<_, String>(1)?, row.get::<_, i64>(3)?)))
            .unwrap()
            .map(|r| r.unwrap())
            .collect();
        let org_col = columns
            .iter()
            .find(|(name, _)| name == "organization_id")
            .unwrap_or_else(|| panic!("table {table} should have organization_id column"));
        assert_eq!(
            org_col.1, 0,
            "organization_id on {table} should be nullable (notnull=0)"
        );
    }

    let expected_indexes = [
        "index_farms_on_organization_id",
        "index_crops_on_organization_id",
        "index_cultivation_plans_on_organization_id",
        "index_fields_on_organization_id",
        "index_agricultural_tasks_on_organization_id",
        "index_fertilizes_on_organization_id",
        "index_interaction_rules_on_organization_id",
        "index_pests_on_organization_id",
        "index_pesticides_on_organization_id",
        "index_organization_memberships_on_organization_id",
        "index_organization_memberships_on_user_id",
    ];
    for index_name in expected_indexes {
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = ?1",
                [index_name],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1, "index {index_name} should exist after schema run");
    }

    assert!(
        schema::embedded_primary_latest_version() >= 16,
        "embedded primary schema should be at least v16"
    );
}

#[test]
fn schema_run_replaces_global_fertilize_name_unique_with_per_user_index() {
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

    let conn = Connection::open(&primary).unwrap();

    let global_unique: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master
             WHERE type = 'index' AND name = 'index_fertilizes_on_name'
               AND sql LIKE '%UNIQUE%'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(
        0, global_unique,
        "global UNIQUE on fertilizes.name must be removed (issue #1114)"
    );

    let per_user_unique: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = 'index_fertilizes_on_user_id_and_name'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(
        1, per_user_unique,
        "per-user fertilize name uniqueness index should exist"
    );

    assert!(
        schema::embedded_primary_latest_version() >= 24,
        "embedded primary schema should be at least v24"
    );
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
