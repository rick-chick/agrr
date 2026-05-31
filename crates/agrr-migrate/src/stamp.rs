use crate::config::DbPaths;
use crate::manifest::LegacyManifest;
use anyhow::Context;
use rusqlite::Connection;
use std::path::Path;

pub fn stamp_schema_legacy(paths: &DbPaths, dry_run: bool) -> anyhow::Result<()> {
    use crate::schema::primary_embedded;

    let manifest = LegacyManifest::load(&paths.app_root)?;

    if dry_run {
        println!(
            "[dry-run] would copy refinery_schema_history from fresh migrate into {}",
            paths.primary.display()
        );
        return Ok(());
    }

    let conn = open_db(&paths.primary)?;
    let temp = tempfile::NamedTempFile::new()?;
    let mut temp_conn = Connection::open(temp.path())?;
    primary_embedded::migrations::runner()
        .run(&mut temp_conn)
        .map_err(|e| anyhow::anyhow!("temp primary migrate for stamp: {e}"))?;

    copy_refinery_history_up_to(&temp_conn, &conn, 1)?;

    if table_exists(&conn, "schema_migrations")? {
        for v in &manifest.primary {
            if v.tag == "ddl" || v.tag == "mixed" {
                insert_schema_migration(&conn, &v.version)?;
            }
        }
    }

    if paths.cache.exists() || paths.cache.parent().is_some_and(|p| p.exists()) {
        if let Some(parent) = paths.cache.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let cache_conn = Connection::open(&paths.cache)?;
        let temp_cache = tempfile::NamedTempFile::new()?;
        let mut temp_cache_conn = Connection::open(temp_cache.path())?;
        crate::schema::cache_embedded::migrations::runner()
            .run(&mut temp_cache_conn)
            .map_err(|e| anyhow::anyhow!("temp cache migrate for stamp: {e}"))?;
        copy_refinery_history(&temp_cache_conn, &cache_conn, None)?;
    }

    crate::schema::run_primary(&paths.primary)?;
    if paths.cache.parent().is_some_and(|p| p.exists()) {
        if let Some(parent) = paths.cache.parent() {
            std::fs::create_dir_all(parent)?;
        }
        crate::schema::run_cache(&paths.cache)?;
    }

    println!("stamped schema history (refinery) on primary and cache");
    Ok(())
}

fn copy_refinery_history_up_to(from: &Connection, to: &Connection, max_version: i32) -> anyhow::Result<()> {
    copy_refinery_history(from, to, Some(max_version))
}

fn copy_refinery_history(from: &Connection, to: &Connection, max_version: Option<i32>) -> anyhow::Result<()> {
    to.execute_batch(
        "CREATE TABLE IF NOT EXISTS refinery_schema_history (
            version INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            applied_on TEXT NOT NULL,
            checksum TEXT NOT NULL
        );",
    )?;
    let mut stmt = from.prepare(
        "SELECT version, name, applied_on, checksum FROM refinery_schema_history ORDER BY version",
    )?;
    let rows = stmt.query_map([], |row| {
        Ok((
            row.get::<_, i32>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, String>(3)?,
        ))
    })?;
    for row in rows {
        let (version, name, applied_on, checksum) = row?;
        if let Some(max) = max_version {
            if version > max {
                continue;
            }
        }
        to.execute(
            "INSERT OR REPLACE INTO refinery_schema_history (version, name, applied_on, checksum)
             VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![version, name, applied_on, checksum],
        )?;
    }
    Ok(())
}

pub fn stamp_data_legacy(paths: &DbPaths, dry_run: bool) -> anyhow::Result<()> {
    let manifest = LegacyManifest::load(&paths.app_root)?;
    let conn = open_db(&paths.primary)?;
    let now = time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".to_string());

    for entry in manifest.all_data_versions() {
        let region = &entry.region;
        let kind = entry.kind.as_deref().unwrap_or("unknown");
        if dry_run {
            println!(
                "[dry-run] data_migration_history {} region={} kind={}",
                entry.version, region, kind
            );
            continue;
        }
        conn.execute(
            "INSERT OR IGNORE INTO data_migration_history (version, region, kind, applied_at) VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![entry.version, region, kind, now],
        )?;
    }
    if !dry_run {
        println!("stamped data_migration_history from legacy manifest");
    }
    Ok(())
}

fn open_db(path: &Path) -> anyhow::Result<Connection> {
    if !path.exists() {
        anyhow::bail!("database not found: {}", path.display());
    }
    Connection::open(path).with_context(|| format!("open {}", path.display()))
}

fn insert_schema_migration(conn: &Connection, version: &str) -> anyhow::Result<()> {
    conn.execute(
        "INSERT OR IGNORE INTO schema_migrations (version) VALUES (?1)",
        [version],
    )?;
    Ok(())
}

fn table_exists(conn: &Connection, name: &str) -> anyhow::Result<bool> {
    let n: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?1",
        [name],
        |r| r.get(0),
    )?;
    Ok(n > 0)
}
