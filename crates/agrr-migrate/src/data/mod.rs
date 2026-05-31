mod apply;
mod base;
mod context;
mod dev_fixtures;
mod nutrients;
mod pests;
mod repairs;
mod tasks;
mod templates;
pub mod weather_stream;

use crate::config::DbPaths;
use crate::manifest::{self, LegacyManifest, DATA_KINDS};
use anyhow::Context;
use rusqlite::Connection;

pub use apply::{ensure_history_table, is_applied};

pub fn list(paths: &DbPaths) -> anyhow::Result<()> {
    let manifest = LegacyManifest::load(&paths.app_root)?;
    let conn = if paths.primary.exists() {
        Some(Connection::open(&paths.primary)?)
    } else {
        None
    };

    println!("Available data kinds: {}", DATA_KINDS.join(", "));
    println!("blueprints: not_implemented (see P7-MIGRATION-RUNBOOK)");
    for kind in DATA_KINDS {
        println!("\n[{kind}]");
        for region in ["jp", "in", "us"] {
            let entries = manifest.data_entries_for(region, kind);
            if entries.is_empty() {
                continue;
            }
            for e in entries {
                let applied = conn
                    .as_ref()
                    .and_then(|c| apply::is_applied(c, &e.version).ok())
                    .unwrap_or(false);
                let mark = if applied { "applied" } else { "pending" };
                println!("  {mark} {} region={} {}", e.version, e.region, e.name);
            }
        }
    }
    Ok(())
}

pub fn apply(paths: &DbPaths, regions_raw: &str, kinds_raw: &str) -> anyhow::Result<()> {
    if !paths.primary.exists() {
        crate::schema::run_primary(&paths.primary)?;
    } else {
        let conn = rusqlite::Connection::open(&paths.primary)?;
        let has_refinery: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='refinery_schema_history'",
            [],
            |r| r.get(0),
        )?;
        if has_refinery == 0 {
            crate::schema::run_primary(&paths.primary)?;
        }
    }

    let manifest = LegacyManifest::load(&paths.app_root)?;
    let regions = manifest::parse_regions(regions_raw);
    let kinds = manifest::parse_kinds(kinds_raw);

    let mut conn = Connection::open(&paths.primary)
        .with_context(|| format!("open {}", paths.primary.display()))?;

    for kind in &kinds {
        apply::apply_kind(paths, &manifest, &mut conn, &regions, kind)?;
    }
    Ok(())
}
