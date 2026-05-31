//! Parity: `test/adapters/field/gateways/field_active_record_gateway_test.rb`

use super::field_gateway::FieldSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::field::gateways::FieldGateway;
use rusqlite::params;

fn field_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_field_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "field_gw_{}_{}.sqlite3",
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
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL,
              latitude REAL, longitude REAL, region TEXT, is_reference INTEGER NOT NULL DEFAULT 0,
              created_at TEXT, updated_at TEXT, weather_data_status TEXT,
              weather_data_fetched_years INTEGER, weather_data_total_years INTEGER,
              weather_data_last_error TEXT, weather_location_id INTEGER,
              last_broadcast_at REAL, predicted_weather_data TEXT
            );
            CREATE TABLE fields (
              id INTEGER PRIMARY KEY, name TEXT NOT NULL, area REAL, daily_fixed_cost REAL,
              region TEXT, farm_id INTEGER NOT NULL, user_id INTEGER,
              created_at TEXT, updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_farm(pool: &SqlitePool, user_id: i64) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (user_id, name, latitude, longitude, region, is_reference,
             weather_data_status, weather_data_fetched_years, weather_data_total_years, created_at, updated_at)
             VALUES (?1, 'Farm', 35.0, 139.0, 'jp', 0, 'pending', 0, 0, datetime('now'), datetime('now'))",
            params![user_id],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

fn insert_field(pool: &SqlitePool, farm_id: i64, user_id: i64, name: &str, area: f64) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO fields (name, area, daily_fixed_cost, farm_id, user_id, created_at, updated_at)
             VALUES (?1, ?2, 0, ?3, ?4, datetime('now'), datetime('now'))",
            params![name, area, farm_id, user_id],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

// Ruby: get_total_area_by_farm_id sums field areas
#[test]
fn get_total_area_by_farm_id_sums_field_areas() {
    let pool = field_test_pool();
    let farm_id = insert_farm(&pool, 1);
    insert_field(&pool, farm_id, 1, "A", 10.5);
    insert_field(&pool, farm_id, 1, "B", 20.0);
    let gw = FieldSqliteGateway::new(pool);
    let total = gw.get_total_area_by_farm_id(farm_id).unwrap();
    assert!((total - 30.5).abs() < 0.001);
}

// Ruby: farm_fields_list returns fields for farm
#[test]
fn farm_fields_list_returns_fields_for_farm() {
    let pool = field_test_pool();
    let farm_id = insert_farm(&pool, 1);
    insert_field(&pool, farm_id, 1, "North", 1.0);
    let gw = FieldSqliteGateway::new(pool);
    let list = gw.farm_fields_list(farm_id).unwrap();
    assert_eq!(list.fields.len(), 1);
    assert_eq!(list.fields[0].name, "North");
}
