//! Scheduler farm list read (`Update*WeatherDataJob` scopes).

use agrr_domain::internal_jobs::dtos::SchedulerWeatherFarmRow;
use agrr_domain::internal_jobs::gateways::SchedulerWeatherFarmListGateway;
use time::Date;

use crate::pool::SqlitePool;

pub struct SchedulerWeatherFarmListSqliteGateway {
    pool: SqlitePool,
}

impl SchedulerWeatherFarmListSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn parse_date(s: &str) -> Option<Date> {
    Date::parse(s.trim(), &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
}

impl SchedulerWeatherFarmListGateway for SchedulerWeatherFarmListSqliteGateway {
    fn list_reference_farms_for_weather_update(
        &self,
    ) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT id, latitude, longitude FROM farms \
                     WHERE is_reference = 1 \
                       AND latitude IS NOT NULL \
                       AND longitude IS NOT NULL \
                     ORDER BY latitude DESC",
                )?;
                let rows = stmt.query_map([], |row| {
                    Ok(SchedulerWeatherFarmRow {
                        farm_id: row.get(0)?,
                        latitude: row.get(1)?,
                        longitude: row.get(2)?,
                        latest_weather_date: None,
                    })
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(|e| e.to_string())
    }

    fn list_user_farms_for_weather_update(&self) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT f.id, f.latitude, f.longitude, \
                            (SELECT MAX(wd.date) FROM weather_data wd \
                             WHERE wd.weather_location_id = f.weather_location_id) AS latest_date \
                     FROM farms f \
                     WHERE f.is_reference = 0 \
                       AND f.weather_location_id IS NOT NULL",
                )?;
                let rows = stmt.query_map([], |row| {
                    let latest_str: Option<String> = row.get(3)?;
                    Ok(SchedulerWeatherFarmRow {
                        farm_id: row.get(0)?,
                        latitude: row.get(1)?,
                        longitude: row.get(2)?,
                        latest_weather_date: latest_str.and_then(|s| parse_date(&s)),
                    })
                })?;
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
mod scheduler_weather_farm_list_gateway_test {
    use super::*;

    fn test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!(
            "agrr_scheduler_farm_list_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "scheduler_farm_{}_{}.sqlite3",
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
                  weather_location_id INTEGER
                );
                CREATE TABLE weather_data (
                  id INTEGER PRIMARY KEY,
                  weather_location_id INTEGER NOT NULL,
                  date TEXT NOT NULL,
                  temperature_max REAL,
                  temperature_min REAL,
                  temperature_mean REAL
                );",
            )
        })
        .unwrap();
        pool
    }

    #[test]
    fn lists_reference_farms_with_coordinates_only() {
        let pool = test_pool();
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_location_id)
                 VALUES (1, 'ref', 35.5, 139.5, 1, NULL)",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_location_id)
                 VALUES (2, 'ref-no-coords', NULL, NULL, 1, NULL)",
                [],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = SchedulerWeatherFarmListSqliteGateway::new(pool);
        let farms = gw.list_reference_farms_for_weather_update().unwrap();
        assert_eq!(farms.len(), 1);
        assert_eq!(farms[0].farm_id, 1);
    }

    #[test]
    fn lists_user_farms_with_weather_location_and_latest_date() {
        let pool = test_pool();
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_location_id, user_id)
                 VALUES (10, 'user', 36.0, 140.0, 0, 5, 1)",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_location_id, user_id)
                 VALUES (11, 'no-wl', 36.0, 140.0, 0, NULL, 1)",
                [],
            )?;
            conn.execute(
                "INSERT INTO weather_data (weather_location_id, date, temperature_max, temperature_min, temperature_mean)
                 VALUES (5, '2026-04-28', 20, 10, 15)",
                [],
            )?;
            Ok(())
        })
        .unwrap();

        let gw = SchedulerWeatherFarmListSqliteGateway::new(pool);
        let farms = gw.list_user_farms_for_weather_update().unwrap();
        assert_eq!(farms.len(), 1);
        assert_eq!(farms[0].farm_id, 10);
        assert_eq!(
            farms[0].latest_weather_date,
            Some(Date::from_calendar_date(2026, time::Month::April, 28).unwrap())
        );
    }
}
