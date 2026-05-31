//! One-off reference data repairs (Rust-only; manifest version per repair).

use super::base;
use rusqlite::Connection;
use std::path::Path;

pub fn apply(
    conn: &mut Connection,
    app_root: &Path,
    region: &str,
    migration_name: &str,
) -> anyhow::Result<()> {
    match (region, migration_name) {
        ("in", "repair_india_reference_farms") => {
            base::repair_india_reference_farms(conn, app_root)
        }
        ("in", "repair_india_reference_crops") => {
            base::repair_india_reference_crops(conn, app_root)
        }
        (other_region, name) => {
            anyhow::bail!("repair kind has no implementation for region={other_region} name={name}")
        }
    }
}
