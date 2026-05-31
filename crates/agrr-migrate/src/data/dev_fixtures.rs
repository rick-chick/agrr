use super::context::{self, ensure_admin_user, with_transaction};
use rusqlite::{params, Connection};
use std::path::Path;

pub fn apply(conn: &mut Connection, _app_root: &Path, region: &str) -> anyhow::Result<()> {
    let _admin_id = ensure_admin_user(conn)?;
    seed_sample_fields(conn, region)?;
    Ok(())
}

fn seed_sample_fields(conn: &mut Connection, region: &str) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    let mut field_count = 0usize;

    with_transaction(conn, |tx| {
        let mut stmt = tx.prepare(
            "SELECT id, name FROM farms WHERE is_reference = 1 AND region = ?1 ORDER BY id LIMIT 5",
        )?;
        let farms: Vec<(i64, String)> = stmt
            .query_map(params![region], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<Result<Vec<_>, _>>()?;

        for (farm_index, (farm_id, farm_name)) in farms.iter().enumerate() {
            let prefix: String = farm_name
                .chars()
                .filter(|c| *c != '県' && *c != '市')
                .take(3)
                .collect();
            for i in 0..2 {
                let field_name = format!("{prefix}-{}", i + 1);
                let existing: Option<i64> = tx
                    .query_row(
                        "SELECT id FROM fields WHERE farm_id = ?1 AND name = ?2 AND region = ?3",
                        params![farm_id, field_name, region],
                        |r| r.get(0),
                    )
                    .optional()
                    .ok()
                    .flatten();

                if existing.is_some() {
                    continue;
                }

                let area = 100.0 + (farm_index as f64) * 10.0 + (i as f64);
                tx.execute(
                    "INSERT INTO fields (farm_id, name, area, region, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?5)",
                    params![farm_id, field_name, area, region, now],
                )?;
                field_count += 1;
            }
        }
        Ok(())
    })?;

    println!("  dev_fixtures/{region}: {field_count} sample fields created");
    Ok(())
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
