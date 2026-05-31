//! Parity: `test/adapters/farm/gateways/farm_active_record_gateway_test.rb`

use super::farm_gateway::FarmSqliteGateway;
use crate::pool::SqlitePool;
use crate::WeatherDataFarmSqliteGateway;
use agrr_domain::farm::gateways::FarmGateway;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::shared::user::User;
use agrr_domain::weather_data::gateways::WeatherDataFarmGateway;
use rusqlite::params;

fn farm_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_farm_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "farm_gw_{}_{}.sqlite3",
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
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_farm(
    pool: &SqlitePool,
    user_id: i64,
    name: &str,
    is_reference: bool,
    latitude: f64,
    longitude: f64,
    region: &str,
) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO farms (user_id, name, latitude, longitude, region, is_reference, \
             weather_data_status, weather_data_fetched_years, weather_data_total_years, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'pending', 0, 0, datetime('now'), datetime('now'))",
            params![
                user_id,
                name,
                latitude,
                longitude,
                region,
                if is_reference { 1 } else { 0 }
            ],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

// Ruby: list_user_and_reference_farms includes user farm and reference farm
#[test]
fn list_user_and_reference_farms_includes_user_farm_and_reference_farm() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let gw = FarmSqliteGateway::new(pool.clone());
    let user_farm = insert_farm(&pool, user.id, "User farm", false, 35.0, 139.0, "jp");
    let reference_farm = insert_farm(&pool, 0, "Ref farm", true, 36.0, 140.0, "jp");

    let farm_ids: Vec<i64> = gw
        .list_user_and_reference_farms(user.id)
        .unwrap()
        .into_iter()
        .map(|f| f.id)
        .collect();

    assert!(farm_ids.contains(&user_farm));
    assert!(farm_ids.contains(&reference_farm));
}

// Ruby: list_user_owned_farms excludes reference farms
#[test]
fn list_user_owned_farms_excludes_reference_farms() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let gw = FarmSqliteGateway::new(pool.clone());
    let user_farm = insert_farm(&pool, user.id, "User farm", false, 35.0, 139.0, "jp");
    let reference_farm = insert_farm(&pool, 0, "Ref farm", true, 36.0, 140.0, "jp");

    let farm_ids: Vec<i64> = gw
        .list_user_owned_farms(user.id)
        .unwrap()
        .into_iter()
        .map(|f| f.id)
        .collect();

    assert!(farm_ids.contains(&user_farm));
    assert!(!farm_ids.contains(&reference_farm));
}

// Ruby: should find farm by id
#[test]
fn find_by_id_returns_farm_entity() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let gw = FarmSqliteGateway::new(pool.clone());
    let farm_id = insert_farm(&pool, user.id, "テスト農場", false, 35.0, 139.0, "jp");

    let entity = gw.find_by_id(farm_id).unwrap();
    assert_eq!(entity.id, farm_id);
    assert_eq!(entity.name, "テスト農場");
}

// Ruby: should raise domain RecordNotFound when farm not found
#[test]
fn find_by_id_raises_record_not_found_when_missing() {
    let pool = farm_test_pool();
    let gw = FarmSqliteGateway::new(pool);
    let err = gw.find_by_id(9999).unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
}

// Ruby: should create farm
#[test]
fn create_for_user_persists_new_farm() {
    let pool = farm_test_pool();
    let user = User::new(5, false);
    let gw = FarmSqliteGateway::new(pool);

    let entity = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("新規農場")),
                ("region", AttrValue::from("jp")),
                ("latitude", AttrValue::Str("35.6895".into())),
                ("longitude", AttrValue::Str("139.6917".into())),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();

    assert_eq!(entity.name, "新規農場");
    assert_eq!(entity.region.as_deref(), Some("jp"));
    assert!((entity.latitude.unwrap() - 35.6895).abs() < f64::EPSILON);
    assert!((entity.longitude.unwrap() - 139.6917).abs() < f64::EPSILON);
    assert_eq!(entity.user_id, Some(user.id));
    assert!(!entity.is_reference);
}

// Ruby: should update farm
#[test]
fn update_for_user_updates_farm_attributes() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let gw = FarmSqliteGateway::new(pool.clone());
    let farm_id = insert_farm(&pool, user.id, "元の農場", false, 35.6895, 139.6917, "jp");

    let entity = gw
        .update_for_user(
            &user,
            farm_id,
            attr_map_from_pairs([
                ("name", AttrValue::from("更新農場")),
                ("latitude", AttrValue::Str("36.6895".into())),
            ]),
        )
        .unwrap();

    assert_eq!(entity.name, "更新農場");
    assert!((entity.latitude.unwrap() - 36.6895).abs() < f64::EPSILON);
    assert!((entity.longitude.unwrap() - 139.6917).abs() < f64::EPSILON);
}

// Ruby: list_reference_farms returns all reference farm entities
#[test]
fn list_reference_farms_returns_reference_farm_entities() {
    let pool = farm_test_pool();
    let gw = FarmSqliteGateway::new(pool.clone());
    insert_farm(&pool, 0, "Ref farm", true, 35.0, 139.0, "jp");

    let ref_entities = gw.list_reference_farms().unwrap();
    assert!(ref_entities.iter().all(|e| e.is_reference));
    assert!(ref_entities.len() >= 1);
}

// Ruby: list_user_owned_farms returns only user non-reference farms
#[test]
fn list_user_owned_farms_returns_only_user_non_reference_farms() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let gw = FarmSqliteGateway::new(pool.clone());
    let user_farm = insert_farm(&pool, user.id, "User farm", false, 35.0, 139.0, "jp");
    insert_farm(&pool, 0, "Ref farm", true, 36.0, 140.0, "jp");

    let farms = gw.list_user_owned_farms(user.id).unwrap();
    assert!(farms.iter().all(|e| !e.is_reference && e.user_id == Some(user.id)));
    assert!(farms.iter().any(|e| e.id == user_farm));
}

// Ruby: farm_weather_data_access_context_for_owned_farm returns dto for owner
#[test]
fn farm_weather_data_access_context_for_owned_farm_returns_context_for_owner() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let farm_id = insert_farm(&pool, user.id, "Weather farm", false, 35.0, 139.0, "jp");
    pool.with_write(|conn| {
        conn.execute(
            "UPDATE farms SET weather_location_id = 42 WHERE id = ?1",
            params![farm_id],
        )
    })
    .unwrap();

    let weather_gw = WeatherDataFarmSqliteGateway::new(pool);
    let ctx = weather_gw
        .farm_weather_data_access_context_for_owned_farm(user.id, farm_id)
        .expect("context");
    assert_eq!(ctx.farm_id, farm_id);
    assert_eq!(ctx.weather_location_id, Some(42));
}

// Ruby: farm_weather_data_access_context_for_owned_farm returns nil for other users farm
#[test]
fn farm_weather_data_access_context_for_owned_farm_returns_none_for_other_users_farm() {
    let pool = farm_test_pool();
    let user = User::new(1, false);
    let other = User::new(2, false);
    let farm_id = insert_farm(&pool, other.id, "Other farm", false, 35.0, 139.0, "jp");

    let weather_gw = WeatherDataFarmSqliteGateway::new(pool);
    let ctx = weather_gw.farm_weather_data_access_context_for_owned_farm(user.id, farm_id);
    assert!(ctx.is_none());
}

// Ruby: farm_weather_data_access_context_for_admin_lookup returns any farm by id
#[test]
fn farm_weather_data_access_context_for_admin_lookup_returns_any_farm_by_id() {
    let pool = farm_test_pool();
    let other = User::new(2, false);
    let farm_id = insert_farm(&pool, other.id, "Other farm", false, 35.0, 139.0, "jp");

    let weather_gw = WeatherDataFarmSqliteGateway::new(pool);
    let ctx = weather_gw
        .farm_weather_data_access_context_for_admin_lookup(farm_id)
        .expect("context");
    assert_eq!(ctx.farm_id, farm_id);
}

// Rust fetch block: MarkFarmWeatherDataFailedInteractor persists last_error (domain + sqlite adapter).
#[test]
fn update_weather_progress_persists_weather_data_last_error() {
    use agrr_domain::farm::dtos::MarkFarmWeatherDataFailedInput;
    use agrr_domain::farm::interactors::MarkFarmWeatherDataFailedInteractor;

    let pool = farm_test_pool();
    let farm_id = insert_farm(&pool, 1, "Test", false, 35.0, 139.0, "jp");
    let gw = FarmSqliteGateway::new(pool.clone());
    MarkFarmWeatherDataFailedInteractor::new(&gw)
        .call(MarkFarmWeatherDataFailedInput {
            farm_id,
            error_message: "fetch weather data failed: WeatherDataStorageFailed".into(),
        })
        .expect("mark failed");

    let last_error: Option<String> = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT weather_data_last_error FROM farms WHERE id = ?1",
                params![farm_id],
                |row| row.get(0),
            )
        })
        .expect("read");
    assert!(
        last_error
            .as_deref()
            .is_some_and(|msg| msg.contains("WeatherDataStorageFailed"))
    );
    let status: String = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT weather_data_status FROM farms WHERE id = ?1",
                params![farm_id],
                |row| row.get(0),
            )
        })
        .expect("status");
    assert_eq!(status, "failed");
}
