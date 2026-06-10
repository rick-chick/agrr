use agrr_migrate::config::DbPaths;
use agrr_migrate::schema;
use std::path::{Path, PathBuf};
use tempfile::TempDir;

pub fn repo_root() -> PathBuf {
    std::env::current_dir()
        .unwrap()
        .ancestors()
        .find(|p| p.join("Cargo.toml").exists() && p.join("crates/agrr-migrate").is_dir())
        .expect("repo root from test cwd")
        .to_path_buf()
}

pub fn test_paths(dir: &Path) -> DbPaths {
    DbPaths {
        app_root: repo_root(),
        primary: dir.join("primary.sqlite3"),
        cache: dir.join("cache.sqlite3"),
    }
}

pub fn setup_schema(dir: &Path) -> DbPaths {
    let paths = test_paths(dir);
    schema::run(&paths).expect("schema run");
    paths
}

pub fn apply_data(paths: &DbPaths, regions: &str, kinds: &str) {
    agrr_migrate::data::apply(paths, regions, kinds).expect("data apply");
}

pub fn apply_repair(paths: &DbPaths, region: &str, migration_name: &str) {
    agrr_migrate::data::apply_repair_migration(paths, region, migration_name)
        .unwrap_or_else(|e| panic!("repair {migration_name}: {e}"));
}

fn use_coords_weather_fixture(relative_path: &str) {
    std::env::set_var("AGRR_MIGRATE_SKIP_WEATHER", "1");
    let fixture = repo_root().join(relative_path);
    std::env::set_var(
        "AGRR_MIGRATE_WEATHER_FIXTURE",
        fixture.to_string_lossy().into_owned(),
    );
}

/// Speeds up JP base/templates tests: coords-only fixture instead of full weather JSON (116 MiB).
pub fn use_jp_coords_weather_fixture() {
    use_coords_weather_fixture("crates/agrr-migrate/tests/fixtures/reference_weather_coords.json");
}

/// Speeds up India farm/repair tests: coords-only fixture (4 KiB) instead of full weather JSON (131 MiB).
pub fn use_india_coords_weather_fixture() {
    use_coords_weather_fixture("crates/agrr-migrate/tests/fixtures/india_reference_weather_coords.json");
}

pub fn count_query(conn: &rusqlite::Connection, sql: &str) -> i64 {
    conn.query_row(sql, [], |r| r.get(0)).unwrap()
}

pub struct TestDb {
    pub _dir: TempDir,
    pub paths: DbPaths,
}

impl TestDb {
    pub fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let paths = setup_schema(dir.path());
        Self { _dir: dir, paths }
    }

    pub fn conn(&self) -> rusqlite::Connection {
        rusqlite::Connection::open(&self.paths.primary).unwrap()
    }
}
