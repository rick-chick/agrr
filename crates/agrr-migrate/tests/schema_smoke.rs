use agrr_migrate::config::DbPaths;
use agrr_migrate::schema;
use tempfile::tempdir;

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
