//! Lists user farms stuck at `pending` for weather backfill.

use agrr_domain::farm::gateways::PendingFarmWeatherBackfillGateway;

use crate::pool::SqlitePool;

pub struct PendingFarmWeatherBackfillSqliteGateway {
    pool: SqlitePool,
}

impl PendingFarmWeatherBackfillSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl PendingFarmWeatherBackfillGateway for PendingFarmWeatherBackfillSqliteGateway {
    fn list_user_farm_ids_pending_initial_weather_fetch(
        &self,
    ) -> Result<Vec<i64>, String> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT f.id FROM farms f \
                     WHERE f.is_reference = 0 \
                       AND f.latitude IS NOT NULL \
                       AND f.longitude IS NOT NULL \
                       AND (f.weather_data_status = 'pending' OR f.weather_data_status IS NULL) \
                     ORDER BY f.id",
                )?;
                let rows = stmt.query_map([], |row| row.get::<_, i64>(0))?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod pending_farm_weather_backfill_gateway_test {
    use super::*;

    fn test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!(
            "agrr_pending_weather_backfill_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "backfill_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (
                  id INTEGER PRIMARY KEY,
                  user_id INTEGER,
                  name TEXT NOT NULL,
                  latitude REAL,
                  longitude REAL,
                  is_reference INTEGER NOT NULL DEFAULT 0,
                  weather_data_status TEXT
                );",
            )
        })
        .unwrap();
        pool
    }

    #[test]
    fn lists_pending_user_farms_with_coordinates_only() {
        let pool = test_pool();
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, is_reference, weather_data_status)
                 VALUES (1, 10, 'pending-user', 35.0, 139.0, 0, 'pending')",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, is_reference, weather_data_status)
                 VALUES (2, 10, 'fetching-user', 35.0, 139.0, 0, 'fetching')",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, is_reference, weather_data_status)
                 VALUES (3, 10, 'no-coords', NULL, NULL, 0, 'pending')",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, is_reference, weather_data_status)
                 VALUES (4, NULL, 'ref-pending', 35.0, 139.0, 1, 'pending')",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, user_id, name, latitude, longitude, is_reference, weather_data_status)
                 VALUES (5, 10, 'null-status', 35.0, 139.0, 0, NULL)",
                [],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = PendingFarmWeatherBackfillSqliteGateway::new(pool);
        let ids = gw
            .list_user_farm_ids_pending_initial_weather_fetch()
            .unwrap();
        assert_eq!(vec![1, 5], ids);
    }
}
