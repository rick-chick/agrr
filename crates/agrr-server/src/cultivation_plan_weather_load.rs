//! Load weather DTOs for cultivation-plan REST / optimization (Ruby AR preload parity).

use agrr_adapters_sqlite::cultivation_plan::planning_horizon::derive_planning_horizon;
use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::dtos::{
    CultivationPlanWeather, PredictedWeatherScope, WeatherLocation,
};
use agrr_domain::weather_data::gateways::PredictedWeatherMetadataGateway;
use std::sync::Arc;
use time::OffsetDateTime;

pub(crate) fn load_weather_location_by_id(
    pool: &SqlitePool,
    weather_location_id: i64,
) -> Result<WeatherLocation, String> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT id, latitude, longitude, elevation, timezone \
             FROM weather_locations WHERE id = ?1",
            rusqlite::params![weather_location_id],
            |row| {
                Ok(WeatherLocation::new(
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            },
        )
    })
    .map_err(|e| e.to_string())
}

pub(crate) fn load_weather_location(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<WeatherLocation, String> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT wl.id, wl.latitude, wl.longitude, wl.elevation, wl.timezone \
             FROM cultivation_plans cp \
             INNER JOIN farms f ON f.id = cp.farm_id \
             INNER JOIN weather_locations wl ON wl.id = f.weather_location_id \
             WHERE cp.id = ?1",
            rusqlite::params![plan_id],
            |row| {
                Ok(WeatherLocation::new(
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            },
        )
    })
    .map_err(|e| e.to_string())
}

pub(crate) fn load_plan_weather(
    pool: &SqlitePool,
    metadata: &Arc<dyn PredictedWeatherMetadataGateway>,
    plan_id: i64,
) -> Result<CultivationPlanWeather, String> {
    let today = OffsetDateTime::now_utc().date();
    let horizon = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT cp.plan_type, cp.plan_year, cp.planning_start_date, cp.planning_end_date, \
                 (SELECT MIN(fc.start_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id), \
                 (SELECT MAX(fc.completion_date) FROM field_cultivations fc \
                  WHERE fc.cultivation_plan_id = cp.id) \
                 FROM cultivation_plans cp WHERE cp.id = ?1",
                rusqlite::params![plan_id],
                |row| {
                    let plan_type: String = row.get(0)?;
                    let plan_year: Option<i32> = row.get(1)?;
                    let planning_start: Option<String> = row.get(2)?;
                    let planning_end: Option<String> = row.get(3)?;
                    let fc_min: Option<String> = row.get(4)?;
                    let fc_max: Option<String> = row.get(5)?;
                    Ok(derive_planning_horizon(
                        &plan_type,
                        plan_year,
                        planning_start.as_deref(),
                        planning_end.as_deref(),
                        fc_min.as_deref(),
                        fc_max.as_deref(),
                        today,
                    ))
                },
            )
        })
        .map_err(|e| e.to_string())?;

    let plan_metadata = metadata
        .find(PredictedWeatherScope::Plan, plan_id)
        .map_err(|e| e.to_string())?;

    Ok(CultivationPlanWeather::new(
        plan_id,
        horizon.prediction_target_end_date,
        horizon.calculated_planning_end_date,
        plan_metadata,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};
    use tempfile::NamedTempFile;
    use time::{Date, Month};

    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), day).unwrap()
    }

    struct FakeMetadataGateway {
        rows: Arc<Mutex<HashMap<(PredictedWeatherScope, i64), PredictedWeatherMetadata>>>,
    }

    impl FakeMetadataGateway {
        fn with_plan_metadata(plan_id: i64, metadata: PredictedWeatherMetadata) -> Self {
            let rows = Arc::new(Mutex::new(HashMap::new()));
            rows.lock()
                .expect("lock")
                .insert((PredictedWeatherScope::Plan, plan_id), metadata);
            Self { rows }
        }
    }

    impl PredictedWeatherMetadataGateway for FakeMetadataGateway {
        fn find(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
        ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .rows
                .lock()
                .expect("lock")
                .get(&(scope, scope_id))
                .cloned())
        }

        fn upsert(
            &self,
            _: &PredictedWeatherMetadata,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn copy_plan_metadata(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    fn weather_test_pool() -> (SqlitePool, NamedTempFile) {
        let file = NamedTempFile::new().expect("temp db");
        let path = file.path().to_str().expect("utf8 path");
        let pool = SqlitePool::new(path);
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE weather_locations (
                   id INTEGER PRIMARY KEY,
                   latitude REAL NOT NULL,
                   longitude REAL NOT NULL,
                   elevation REAL,
                   timezone TEXT
                 );
                 CREATE TABLE farms (
                   id INTEGER PRIMARY KEY,
                   name TEXT,
                   latitude REAL NOT NULL,
                   longitude REAL NOT NULL,
                   weather_location_id INTEGER
                 );
                 CREATE TABLE cultivation_plans (
                   id INTEGER PRIMARY KEY,
                   farm_id INTEGER,
                   plan_type TEXT,
                   plan_year INTEGER,
                   planning_start_date TEXT,
                   planning_end_date TEXT
                 );
                 CREATE TABLE field_cultivations (
                   id INTEGER PRIMARY KEY,
                   cultivation_plan_id INTEGER,
                   start_date TEXT,
                   completion_date TEXT
                 );",
            )?;
            conn.execute(
                "INSERT INTO weather_locations (id, latitude, longitude, elevation, timezone)
                 VALUES (7, 35.6, 139.7, 10.0, 'Asia/Tokyo')",
                [],
            )?;
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude, weather_location_id)
                 VALUES (1, 'Farm', 35.6, 139.7, 7)",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (
                   id, farm_id, plan_type, plan_year, planning_start_date, planning_end_date
                 ) VALUES (42, 1, 'private', 2026, '2026-01-01', '2026-12-31')",
                [],
            )?;
            conn.execute(
                "INSERT INTO field_cultivations (cultivation_plan_id, start_date, completion_date)
                 VALUES (42, '2026-03-01', '2026-10-31')",
                [],
            )?;
            Ok(())
        })
        .expect("seed");
        (pool, file)
    }

    #[test]
    fn load_weather_location_by_id_returns_coordinates() {
        let (pool, _file) = weather_test_pool();
        let location = load_weather_location_by_id(&pool, 7).expect("location");
        assert_eq!(location.id, 7);
        assert!((location.latitude - 35.6).abs() < f64::EPSILON);
        assert_eq!(location.timezone.as_deref(), Some("Asia/Tokyo"));
    }

    #[test]
    fn load_weather_location_by_id_errors_when_missing() {
        let (pool, _file) = weather_test_pool();
        let err = load_weather_location_by_id(&pool, 999).expect_err("missing");
        assert!(err.contains("Query returned no rows") || err.contains("no rows"));
    }

    #[test]
    fn load_weather_location_joins_plan_farm_and_location() {
        let (pool, _file) = weather_test_pool();
        let location = load_weather_location(&pool, 42).expect("location");
        assert_eq!(location.id, 7);
        assert!((location.longitude - 139.7).abs() < f64::EPSILON);
    }

    #[test]
    fn load_plan_weather_assembles_horizon_and_metadata() {
        let (pool, _file) = weather_test_pool();
        let metadata = PredictedWeatherMetadata {
            scope: PredictedWeatherScope::Plan,
            scope_id: 42,
            prediction_start_date: d(2026, 1, 1),
            prediction_end_date: d(2026, 12, 31),
            target_end_date: d(2026, 12, 31),
            data_end_date: d(2026, 12, 31),
            generated_at: "2026-01-01T00:00:00Z".into(),
        };
        let gateway: Arc<dyn PredictedWeatherMetadataGateway> =
            Arc::new(FakeMetadataGateway::with_plan_metadata(42, metadata.clone()));
        let dto = load_plan_weather(&pool, &gateway, 42).expect("plan weather");
        assert_eq!(dto.id, 42);
        assert_eq!(dto.prediction_target_end_date, Some(d(2026, 12, 31)));
        assert_eq!(dto.calculated_planning_end_date, Some(d(2026, 12, 31)));
        assert_eq!(dto.plan_metadata, Some(metadata));
    }
}
