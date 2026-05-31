//! `weather_data.date` may be `YYYY-MM-DD` (JP fixtures) or `YYYY-MM-DDTHH:MM:SS` (India fixtures).

use super::weather_data_gateway::WeatherDataSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::weather_data::gateways::WeatherDataGateway;
use time::{Date, Month};

fn weather_gw_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_weather_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "weather_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE weather_locations (id INTEGER PRIMARY KEY);
             CREATE TABLE weather_data (
               weather_location_id INTEGER NOT NULL,
               date TEXT NOT NULL,
               temperature_max REAL,
               temperature_min REAL,
               temperature_mean REAL,
               precipitation REAL,
               sunshine_hours REAL,
               wind_speed REAL,
               weather_code INTEGER,
               created_at TEXT,
               updated_at TEXT
             );",
        )
    })
    .unwrap();
    pool
}

#[test]
fn weather_data_for_period_parses_iso_datetime_date_column() {
    let pool = weather_gw_pool();
    pool.with_write(|conn| {
        conn.execute("INSERT INTO weather_locations (id) VALUES (1)", [])?;
        conn.execute(
            "INSERT INTO weather_data (weather_location_id, date, temperature_max, temperature_min)
             VALUES (1, '2000-01-01T00:00:00', 10.0, 5.0),
                    (1, '2000-01-02T00:00:00', 11.0, 6.0)",
            [],
        )?;
        Ok(())
    })
    .unwrap();

    let gw = WeatherDataSqliteGateway::new(pool);
    let start = Date::from_calendar_date(1999, Month::January, 1).unwrap();
    let end = Date::from_calendar_date(2001, Month::December, 31).unwrap();
    let rows = gw.weather_data_for_period(1, start, end).unwrap();

    assert_eq!(rows.len(), 2);
    assert_ne!(rows[0].date, rows[1].date);
    assert_eq!(rows[0].date.to_string(), "2000-01-01");
    assert_eq!(rows[1].date.to_string(), "2000-01-02");
}
