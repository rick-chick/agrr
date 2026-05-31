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
