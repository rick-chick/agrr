use anyhow::Context;
use rusqlite::{params, Connection, Transaction};
use std::path::Path;
use time::OffsetDateTime;

pub fn now_rfc3339() -> String {
    OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".to_string())
}

pub fn extracted_data_dir(app_root: &Path) -> std::path::PathBuf {
    app_root.join("crates/agrr-migrate/data/extracted")
}

pub fn fixtures_dir(app_root: &Path) -> std::path::PathBuf {
    app_root.join("db/fixtures")
}

pub fn with_transaction<F>(conn: &mut Connection, f: F) -> anyhow::Result<()>
where
    F: FnOnce(&Transaction<'_>) -> anyhow::Result<()>,
{
    let tx = conn
        .transaction()
        .context("begin data migration transaction")?;
    f(&tx)?;
    tx.commit().context("commit data migration transaction")?;
    Ok(())
}

/// Anonymous user required for reference farms (matches Rails seeds).
pub fn ensure_anonymous_user(conn: &Connection) -> anyhow::Result<i64> {
    if let Some(id) = conn
        .query_row(
            "SELECT id FROM users WHERE is_anonymous = 1 LIMIT 1",
            [],
            |r| r.get(0),
        )
        .ok()
    {
        return Ok(id);
    }
    let now = now_rfc3339();
    conn.execute(
        "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at)
         VALUES ('anonymous@agrr.app', 'Anonymous User', NULL, NULL, 1, 0, ?1, ?1)",
        params![now],
    )?;
    Ok(conn.last_insert_rowid())
}

/// Admin user for development fixtures (`dev_fixtures` kind).
pub fn ensure_admin_user(conn: &Connection) -> anyhow::Result<i64> {
    if let Some(id) = conn
        .query_row(
            "SELECT id FROM users WHERE email = 'admin@agrr.app' LIMIT 1",
            [],
            |r| r.get(0),
        )
        .ok()
    {
        conn.execute("UPDATE users SET admin = 1 WHERE id = ?1", params![id])?;
        return Ok(id);
    }
    let now = now_rfc3339();
    conn.execute(
        "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at)
         VALUES ('admin@agrr.app', 'Admin User', NULL, NULL, 0, 1, ?1, ?1)",
        params![now],
    )?;
    Ok(conn.last_insert_rowid())
}

pub fn crop_id_by_name(
    conn: &Connection,
    name: &str,
    region: &str,
) -> anyhow::Result<Option<i64>> {
    conn.query_row(
        "SELECT id FROM crops WHERE name = ?1 AND region = ?2 AND is_reference = 1 LIMIT 1",
        params![name, region],
        |r| r.get(0),
    )
    .optional()
    .map_err(Into::into)
}

/// Resolves crop refs the same way as migrate_archive `TempCrop.find_by(name: ...)`.
pub fn crop_id_resolve(
    conn: &Connection,
    crop_ref: &str,
    region: &str,
) -> anyhow::Result<Option<i64>> {
    crop_id_by_name(conn, crop_ref, region)
}

pub fn agricultural_task_id_by_name(
    conn: &Connection,
    name: &str,
    region: &str,
) -> anyhow::Result<Option<i64>> {
    conn.query_row(
        "SELECT id FROM agricultural_tasks WHERE name = ?1 AND region = ?2 AND is_reference = 1 LIMIT 1",
        params![name, region],
        |r| r.get(0),
    )
    .optional()
    .map_err(Into::into)
}

trait OptionalRow {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error>;
}

impl OptionalRow for Result<i64, rusqlite::Error> {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}
