use crate::config::DbPaths;
use anyhow::Context;
use rusqlite::Connection;
use std::path::Path;

pub mod primary_embedded {
    use refinery::embed_migrations;
    embed_migrations!("migrations/schema");
}

pub mod cache_embedded {
    use refinery::embed_migrations;
    embed_migrations!("migrations/cache_schema");
}

pub fn run(paths: &DbPaths) -> anyhow::Result<()> {
    run_primary(&paths.primary)?;
    if paths.cache.exists() || should_create_cache(paths) {
        if let Some(parent) = paths.cache.parent() {
            std::fs::create_dir_all(parent)?;
        }
        run_cache(&paths.cache)?;
    }
    Ok(())
}

fn should_create_cache(paths: &DbPaths) -> bool {
    paths.cache.parent().is_some_and(|p| p.exists())
}

pub fn run_primary(path: &Path) -> anyhow::Result<()> {
    let mut conn = Connection::open(path).with_context(|| format!("open {}", path.display()))?;
    guard_existing_db_without_refinery(&conn)?;
    primary_embedded::migrations::runner()
        .run(&mut conn)
        .map_err(|e| anyhow::anyhow!("primary schema migrate: {e}"))?;
    Ok(())
}

pub fn run_cache(path: &Path) -> anyhow::Result<()> {
    let mut conn = Connection::open(path).with_context(|| format!("open {}", path.display()))?;
    cache_embedded::migrations::runner()
        .run(&mut conn)
        .map_err(|e| anyhow::anyhow!("cache schema migrate: {e}"))?;
    Ok(())
}

pub fn status(paths: &DbPaths) -> anyhow::Result<()> {
    println!("primary: {}", paths.primary.display());
    print_refinery_version(&paths.primary, "refinery_schema_history")?;
    println!("cache: {}", paths.cache.display());
    if paths.cache.exists() {
        print_refinery_version(&paths.cache, "refinery_schema_history")?;
    }
    Ok(())
}

fn print_refinery_version(db_path: &Path, table: &str) -> anyhow::Result<()> {
    if !db_path.exists() {
        println!("  (database file missing)");
        return Ok(());
    }
    let conn = Connection::open(db_path)?;
    let exists: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?1",
        [table],
        |r| r.get(0),
    )?;
    if exists == 0 {
        println!("  {table}: not present");
        return Ok(());
    }
    let version: Option<i64> = conn
        .query_row(&format!("SELECT MAX(version) FROM {table}"), [], |r| r.get(0))
        .ok();
    println!("  {table} max version: {:?}", version);
    Ok(())
}

/// Required tables that must exist after baseline + V2 on a healthy primary DB.
const REQUIRED_TABLES: &[&str] = &[
    "users",
    "farms",
    "crops",
    "pests",
    "agricultural_tasks",
    "data_migration_history",
];

pub fn verify(paths: &DbPaths) -> anyhow::Result<()> {
    anyhow::ensure!(
        paths.primary.exists(),
        "primary database missing: {}",
        paths.primary.display()
    );
    let conn = Connection::open(&paths.primary)?;
    for table in REQUIRED_TABLES {
        let exists: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?1",
            [*table],
            |r| r.get(0),
        )?;
        anyhow::ensure!(exists == 1, "missing required table: {table}");
    }
    let version: i64 = conn.query_row(
        "SELECT COALESCE(MAX(version), 0) FROM refinery_schema_history",
        [],
        |r| r.get(0),
    )?;
    anyhow::ensure!(version >= 1, "refinery schema not applied (version={version})");
    println!("schema verify OK (refinery version {version})");
    Ok(())
}

/// Refuses baseline on a Litestream-restored DB that already has app tables but no refinery history.
fn guard_existing_db_without_refinery(conn: &Connection) -> anyhow::Result<()> {
    let refinery_exists: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='refinery_schema_history'",
        [],
        |r| r.get(0),
    )?;
    if refinery_exists > 0 {
        return Ok(());
    }
    let app_tables: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT IN (
            'sqlite_sequence', 'schema_migrations', 'ar_internal_metadata'
        )",
        [],
        |r| r.get(0),
    )?;
    if app_tables > 0 {
        anyhow::bail!(
            "database has tables but no refinery_schema_history; run `agrr-migrate schema stamp` \
             (see docs/migration/app-rust-stack/P7-MIGRATION-RUNBOOK.md) before schema run"
        );
    }
    Ok(())
}

pub fn schema_up_to_date(paths: &DbPaths) -> anyhow::Result<bool> {
    if !paths.primary.exists() {
        return Ok(false);
    }
    let conn = Connection::open(&paths.primary)?;
    let exists: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='refinery_schema_history'",
        [],
        |r| r.get(0),
    )?;
    if exists == 0 {
        return Ok(false);
    }
    let current: i64 = conn.query_row(
        "SELECT COALESCE(MAX(version), 0) FROM refinery_schema_history",
        [],
        |r| r.get(0),
    )?;
    Ok(current >= 2)
}
