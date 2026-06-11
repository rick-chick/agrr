//! SQLite `crops.source_crop_id` lookup for add_crop stage backfill.

use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropSourceCropLookupGateway;
use rusqlite::{params, OptionalExtension};

pub struct CropSourceCropLookupSqliteGateway {
    pool: SqlitePool,
}

impl CropSourceCropLookupSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropSourceCropLookupGateway for CropSourceCropLookupSqliteGateway {
    fn find_source_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<i64>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT source_crop_id FROM crops WHERE id = ?1",
                params![crop_id],
                |row| row.get::<_, Option<i64>>(0),
            )
            .optional()
            .map(|opt| opt.flatten())
            .map_err(Into::into)
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn returns_source_crop_id_when_present() {
        let path = std::env::temp_dir().join(format!(
            "agrr_source_crop_lookup_{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&path);
        let conn = Connection::open(&path).unwrap();
        conn.execute_batch(
            "CREATE TABLE crops (id INTEGER PRIMARY KEY, source_crop_id INTEGER);
             INSERT INTO crops (id, source_crop_id) VALUES (53, 10);",
        )
        .unwrap();
        drop(conn);
        let pool = SqlitePool::new(path.to_string_lossy());
        let gw = CropSourceCropLookupSqliteGateway::new(pool);
        assert_eq!(gw.find_source_crop_id(53).unwrap(), Some(10));
    }
}
