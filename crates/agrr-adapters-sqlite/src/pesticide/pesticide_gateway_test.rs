//! Parity: `test/adapters/pesticide/gateways/pesticide_active_record_gateway_test.rb`

use super::pesticide_gateway::PesticideSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::pesticide::gateways::PesticideGateway;
use agrr_domain::shared::policies::pesticide_policy;
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};
use rusqlite::params;

fn pesticide_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_pesticide_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "pesticide_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE crops (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL, variety TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0, area_per_unit REAL, revenue_per_area REAL,
              region TEXT, groups TEXT, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE pests (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL, name_scientific TEXT,
              family TEXT, \"order\" TEXT, description TEXT, occurrence_season TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0, region TEXT, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE pesticides (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL, active_ingredient TEXT,
              description TEXT, crop_id INTEGER, pest_id INTEGER, is_reference INTEGER NOT NULL DEFAULT 0,
              region TEXT, created_at TEXT, updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_crop(
    pool: &SqlitePool,
    user_id: i64,
    name: &str,
    is_reference: bool,
) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO crops (user_id, name, is_reference, groups, created_at, updated_at) \
             VALUES (?1, ?2, ?3, '[]', datetime('now'), datetime('now'))",
            params![user_id, name, if is_reference { 1 } else { 0 }],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

fn insert_pest(
    pool: &SqlitePool,
    user_id: Option<i64>,
    name: &str,
    is_reference: bool,
) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO pests (user_id, name, is_reference, created_at, updated_at) \
             VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
            params![user_id, name, if is_reference { 1 } else { 0 }],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

fn insert_pesticide(
    pool: &SqlitePool,
    user_id: Option<i64>,
    crop_id: i64,
    pest_id: i64,
    name: &str,
    is_reference: bool,
) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO pesticides (user_id, name, crop_id, pest_id, is_reference, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'), datetime('now'))",
            params![
                user_id,
                name,
                crop_id,
                pest_id,
                if is_reference { 1 } else { 0 }
            ],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

// Ruby: list_index_for_filter owned_non_reference returns only that user's non-reference pesticides
#[test]
fn list_index_for_filter_owned_non_reference_returns_only_users_non_reference_pesticides() {
    let pool = pesticide_test_pool();
    let user = User::new(1, false);
    let other = User::new(2, false);
    let gw = PesticideSqliteGateway::new(pool.clone());

    let crop_u = insert_crop(&pool, user.id, "Crop U", false);
    let pest_u = insert_pest(&pool, Some(user.id), "Pest U", false);
    let owned = insert_pesticide(&pool, Some(user.id), crop_u, pest_u, "Mine", false);

    let crop_o = insert_crop(&pool, other.id, "Crop O", false);
    let pest_o = insert_pest(&pool, Some(other.id), "Pest O", false);
    insert_pesticide(&pool, Some(other.id), crop_o, pest_o, "Other", false);

    let crop_r = insert_crop(&pool, 0, "Crop R", true);
    let pest_r = insert_pest(&pool, None, "Pest R", true);
    insert_pesticide(&pool, None, crop_r, pest_r, "Ref", true);

    let filter = pesticide_policy::index_list_filter(&user);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();
    assert_eq!(ids, vec![owned]);
}

// Ruby: list_by_crop_id_for_filter scopes by crop and filter mode
#[test]
fn list_by_crop_id_for_filter_scopes_by_crop_and_filter_mode() {
    let pool = pesticide_test_pool();
    let user = User::new(1, false);
    let gw = PesticideSqliteGateway::new(pool.clone());

    let crop_u = insert_crop(&pool, user.id, "Crop U", false);
    let pest_u = insert_pest(&pool, Some(user.id), "Pest U", false);
    let on_crop = insert_pesticide(&pool, Some(user.id), crop_u, pest_u, "On crop", false);

    let other_crop = insert_crop(&pool, user.id, "Other crop", false);
    insert_pesticide(&pool, Some(user.id), other_crop, pest_u, "Other crop", false);

    let crop_r = insert_crop(&pool, 0, "Crop R", true);
    let pest_r = insert_pest(&pool, None, "Pest R", true);
    insert_pesticide(&pool, None, crop_r, pest_r, "Ref", true);

    let filter = pesticide_policy::index_list_filter(&user);
    let ids: Vec<i64> = gw
        .list_by_crop_id_for_filter(crop_u, &filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();
    assert_eq!(ids, vec![on_crop]);
}

// Ruby: list_index_for_filter reference_or_owned includes reference and admin-owned rows
#[test]
fn list_index_for_filter_reference_or_owned_includes_reference_and_admin_owned_rows() {
    let pool = pesticide_test_pool();
    let admin = User::new(10, true);
    let other = User::new(20, false);
    let gw = PesticideSqliteGateway::new(pool.clone());

    let crop_a = insert_crop(&pool, admin.id, "Crop A", false);
    let pest_a = insert_pest(&pool, Some(admin.id), "Pest A", false);
    let own = insert_pesticide(&pool, Some(admin.id), crop_a, pest_a, "Admin own", false);

    let crop_r = insert_crop(&pool, 0, "Crop R", true);
    let pest_r = insert_pest(&pool, None, "Pest R", true);
    let ref_row = insert_pesticide(&pool, None, crop_r, pest_r, "Ref", true);

    let crop_o = insert_crop(&pool, other.id, "Crop O", false);
    let pest_o = insert_pest(&pool, Some(other.id), "Pest O", false);
    let other_pesticide =
        insert_pesticide(&pool, Some(other.id), crop_o, pest_o, "Other", false);

    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, admin.id);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();

    assert!(ids.contains(&ref_row));
    assert!(ids.contains(&own));
    assert!(!ids.contains(&other_pesticide));
}

// Regression (#35): show detail JOIN must expose related crop and pest names for API/frontend.
#[test]
fn find_pesticide_show_detail_returns_crop_and_pest_names() {
    let pool = pesticide_test_pool();
    let user = User::new(1, false);
    let gw = PesticideSqliteGateway::new(pool.clone());

    let crop_id = insert_crop(&pool, user.id, "Tomato", false);
    let pest_id = insert_pest(&pool, Some(user.id), "Aphid", false);
    let pesticide_id = insert_pesticide(
        &pool,
        Some(user.id),
        crop_id,
        pest_id,
        "Spray A",
        false,
    );

    let detail = gw.find_pesticide_show_detail(pesticide_id).unwrap();

    assert_eq!(detail.pesticide.id, pesticide_id);
    assert_eq!(detail.crop_name.as_deref(), Some("Tomato"));
    assert_eq!(detail.pest_name.as_deref(), Some("Aphid"));
}
