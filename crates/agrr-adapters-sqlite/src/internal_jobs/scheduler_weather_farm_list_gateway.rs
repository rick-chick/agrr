//! Scheduler farm list read (`Update*WeatherDataJob` scopes).

use agrr_domain::internal_jobs::dtos::SchedulerWeatherFarmRow;
use agrr_domain::internal_jobs::gateways::SchedulerWeatherFarmListGateway;
use agrr_domain::weather_data::gateways::WeatherDataGateway;

use crate::pool::SqlitePool;
use time::Date;

fn latest_weather_date_for_location(
    weather_data: &dyn WeatherDataGateway,
    weather_location_id: Option<i64>,
) -> Result<Option<Date>, String> {
    match weather_location_id {
        None => Ok(None),
        Some(id) => weather_data
            .latest_date(id)
            .map_err(|e| e.to_string()),
    }
}

pub struct SchedulerWeatherFarmListSqliteGateway<'a> {
    pool: SqlitePool,
    weather_data: &'a dyn WeatherDataGateway,
}

impl<'a> SchedulerWeatherFarmListSqliteGateway<'a> {
    pub fn new(pool: SqlitePool, weather_data: &'a dyn WeatherDataGateway) -> Self {
        Self { pool, weather_data }
    }
}

impl SchedulerWeatherFarmListGateway for SchedulerWeatherFarmListSqliteGateway<'_> {
    fn list_reference_farms_for_weather_update(
        &self,
    ) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        let rows_data: Vec<(i64, f64, f64, Option<i64>)> = self
            .pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT f.id, f.latitude, f.longitude, f.weather_location_id \
                     FROM farms f \
                     WHERE f.is_reference = 1 \
                       AND f.latitude IS NOT NULL \
                       AND f.longitude IS NOT NULL \
                     ORDER BY f.latitude DESC",
                )?;
                let rows = stmt.query_map([], |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, f64>(1)?,
                        row.get::<_, f64>(2)?,
                        row.get::<_, Option<i64>>(3)?,
                    ))
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(|e| e.to_string())?;

        let mut out = Vec::with_capacity(rows_data.len());
        for (farm_id, latitude, longitude, weather_location_id) in rows_data {
            let latest_weather_date =
                latest_weather_date_for_location(self.weather_data, weather_location_id)?;
            out.push(SchedulerWeatherFarmRow {
                farm_id,
                latitude,
                longitude,
                latest_weather_date,
            });
        }
        Ok(out)
    }

    fn list_user_farms_for_weather_update(&self) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        let rows_data: Vec<(i64, f64, f64, i64)> = self
            .pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT f.id, f.latitude, f.longitude, f.weather_location_id \
                     FROM farms f \
                     WHERE f.is_reference = 0 \
                       AND f.weather_location_id IS NOT NULL",
                )?;
                let rows = stmt.query_map([], |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, f64>(1)?,
                        row.get::<_, f64>(2)?,
                        row.get::<_, i64>(3)?,
                    ))
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(|e| e.to_string())?;

        let mut out = Vec::with_capacity(rows_data.len());
        for (farm_id, latitude, longitude, weather_location_id) in rows_data {
            let latest_weather_date =
                latest_weather_date_for_location(self.weather_data, Some(weather_location_id))?;
            out.push(SchedulerWeatherFarmRow {
                farm_id,
                latitude,
                longitude,
                latest_weather_date,
            });
        }
        Ok(out)
    }
}

#[cfg(test)]
mod scheduler_weather_farm_list_gateway_test {
    use super::*;
    use crate::weather_data::WeatherDataSqliteGateway;
    use time::Date;

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

        let weather = WeatherDataSqliteGateway::new(pool.clone());
        let gw = SchedulerWeatherFarmListSqliteGateway::new(pool, &weather);
        let farms = gw.list_reference_farms_for_weather_update().unwrap();
        assert_eq!(farms.len(), 1);
        assert_eq!(farms[0].farm_id, 1);
        assert!(farms[0].latest_weather_date.is_none());
    }

    #[test]
    fn user_farm_latest_date_reads_sqlite_weather_data_when_sqlite_gateway() {
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

        let weather = WeatherDataSqliteGateway::new(pool.clone());
        let gw = SchedulerWeatherFarmListSqliteGateway::new(pool, &weather);
        let farms = gw.list_user_farms_for_weather_update().unwrap();
        assert_eq!(farms.len(), 1);
        assert_eq!(farms[0].farm_id, 10);
        assert_eq!(
            farms[0].latest_weather_date,
            Some(Date::from_calendar_date(2026, time::Month::April, 28).unwrap())
        );
    }

    #[test]
    fn user_farm_latest_date_reads_gcs_bulk_without_sqlite_weather_rows() {
        use crate::weather_data::gcs_weather_test_support::{
            write_year_fixture, with_local_gcs_root, GcsBulkWeatherGateway,
        };

        with_local_gcs_root(|root| {
            write_year_fixture(
                root,
                5,
                2026,
                r#"{"2026-04-28": {"temperature_max": 20.0, "temperature_min": 10.0}}"#,
            );
            let pool = test_pool();
            pool.with_write(|conn| {
                conn.execute(
                    "INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_location_id, user_id)
                     VALUES (10, 'user', 36.0, 140.0, 0, 5, 1)",
                    [],
                )
            })
            .unwrap();

            let weather = GcsBulkWeatherGateway::from_local_env().expect("gcs gateway");
            let gw = SchedulerWeatherFarmListSqliteGateway::new(pool, &weather);
            let farms = gw.list_user_farms_for_weather_update().unwrap();
            assert_eq!(farms.len(), 1);
            assert_eq!(
                farms[0].latest_weather_date,
                Some(Date::from_calendar_date(2026, time::Month::April, 28).unwrap())
            );
        });
    }
}
