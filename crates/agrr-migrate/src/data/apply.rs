use crate::config::DbPaths;
use crate::manifest::LegacyManifest;
use rusqlite::Connection;

use super::context;
use super::{base, dev_fixtures, nutrients, pests, repairs, tasks, templates};

pub fn apply_kind(
    paths: &DbPaths,
    manifest: &LegacyManifest,
    conn: &mut Connection,
    regions: &[String],
    kind: &str,
) -> anyhow::Result<()> {
    if kind == "blueprints" {
        anyhow::bail!(
            "kind 'blueprints' is not implemented in agrr-migrate (schedule blueprint generation is out of band; see P7-MIGRATION-RUNBOOK.md)"
        );
    }
    if kind == "templates" {
        let jp_only: Vec<String> = regions.iter().filter(|r| *r == "jp").cloned().collect();
        if jp_only.is_empty() {
            println!("skip kind=templates: no jp in --region");
            return Ok(());
        }
        if jp_only.len() < regions.len() {
            println!("note: kind=templates applies to jp only (ignoring other regions)");
        }
        return apply_kind_regions(paths, manifest, conn, &jp_only, kind);
    }
    if kind == "dev_fixtures" {
        let allowed: Vec<String> = regions
            .iter()
            .filter(|r| *r == "jp" || *r == "us")
            .cloned()
            .collect();
        if allowed.is_empty() {
            println!("skip kind=dev_fixtures: need jp or us in --region");
            return Ok(());
        }
        if allowed.len() < regions.len() {
            println!("note: kind=dev_fixtures applies to jp,us only");
        }
        return apply_kind_regions(paths, manifest, conn, &allowed, kind);
    }

    apply_kind_regions(paths, manifest, conn, regions, kind)
}

fn apply_kind_regions(
    paths: &DbPaths,
    manifest: &LegacyManifest,
    conn: &mut Connection,
    regions: &[String],
    kind: &str,
) -> anyhow::Result<()> {
    for region in regions {
        let entries = manifest.data_entries_for(region, kind);
        if entries.is_empty() {
            println!("skip kind={kind} region={region}: no legacy migrations");
            continue;
        }
        for entry in entries {
            if is_applied(conn, &entry.version)? {
                println!("skip {} (already applied)", entry.name);
                continue;
            }
            println!("apply {} (region={region} kind={kind}) ...", entry.name);
            apply_kind_region(paths, conn, region, kind, &entry.name)?;
            record_applied(conn, &entry.version, region, kind)?;
        }
    }
    Ok(())
}

fn apply_kind_region(
    paths: &DbPaths,
    conn: &mut Connection,
    region: &str,
    kind: &str,
    migration_name: &str,
) -> anyhow::Result<()> {
    let app_root = &paths.app_root;
    match kind {
        "base" => base::apply(conn, app_root, region),
        "nutrients" => nutrients::apply(conn, region),
        "pests" => pests::apply(conn, app_root, region),
        "tasks" => tasks::apply(conn, app_root, region),
        "templates" => templates::apply(conn, app_root, region),
        "dev_fixtures" => dev_fixtures::apply(conn, app_root, region),
        "repair" => repairs::apply(conn, app_root, region, migration_name),
        other => anyhow::bail!("unknown data kind: {other}"),
    }
}

pub fn is_applied(conn: &Connection, version: &str) -> anyhow::Result<bool> {
    let n: i64 = conn.query_row(
        "SELECT COUNT(*) FROM data_migration_history WHERE version = ?1",
        [version],
        |r| r.get(0),
    )?;
    Ok(n > 0)
}

pub fn record_applied(
    conn: &mut Connection,
    version: &str,
    region: &str,
    kind: &str,
) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    conn.execute(
        "INSERT OR IGNORE INTO data_migration_history (version, region, kind, applied_at) VALUES (?1, ?2, ?3, ?4)",
        rusqlite::params![version, region, kind, now],
    )?;
    Ok(())
}

pub fn ensure_history_table(conn: &Connection) -> anyhow::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS data_migration_history (
            version TEXT NOT NULL PRIMARY KEY,
            region TEXT NOT NULL,
            kind TEXT NOT NULL,
            applied_at TEXT NOT NULL
        );",
    )?;
    Ok(())
}
