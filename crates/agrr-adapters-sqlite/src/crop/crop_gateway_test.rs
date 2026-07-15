//! Parity: `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` (key masters CRUD reads)

use super::crop_gateway::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::{
    CropStageCreateInput, CropStageUpdateInput, TemperatureRequirementUpdateInput,
};
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::cultivation_plan::ports::PrivatePlanCropListGateway;
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};
use rusqlite::params;
use rust_decimal::Decimal;
use serde_json::json;

fn crop_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_crop_gw_test_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "crop_gw_test_{}_{}.sqlite3",
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
            CREATE TABLE crop_stages (
              id INTEGER PRIMARY KEY, crop_id INTEGER NOT NULL, name TEXT, \"order\" INTEGER,
              created_at TEXT, updated_at TEXT
            );
            CREATE UNIQUE INDEX index_crop_stages_on_crop_id_and_order
              ON crop_stages (crop_id, \"order\");
            CREATE TABLE temperature_requirements (
              id INTEGER PRIMARY KEY, crop_stage_id INTEGER NOT NULL,
              base_temperature REAL, optimal_min REAL, optimal_max REAL,
              low_stress_threshold REAL, high_stress_threshold REAL,
              frost_threshold REAL, sterility_risk_threshold REAL, max_temperature REAL,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE thermal_requirements (
              id INTEGER PRIMARY KEY, crop_stage_id INTEGER NOT NULL,
              required_gdd REAL, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE sunshine_requirements (
              id INTEGER PRIMARY KEY, crop_stage_id INTEGER NOT NULL,
              minimum_sunshine_hours REAL, target_sunshine_hours REAL,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE nutrient_requirements (
              id INTEGER PRIMARY KEY, crop_stage_id INTEGER NOT NULL,
              daily_uptake_n REAL, daily_uptake_p REAL, daily_uptake_k REAL,
              region TEXT, created_at TEXT, updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_crop(pool: &SqlitePool, user_id: i64, name: &str, is_reference: bool) -> i64 {
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

fn seed_crop(pool: &SqlitePool) -> (CropSqliteGateway, i64) {
    let crop_id = insert_crop(pool, 1, "Tomato", false);
    (CropSqliteGateway::new(pool.clone()), crop_id)
}

// Ruby: create_crop_stage creates a new crop stage
#[test]
fn create_crop_stage_creates_new_crop_stage() {
    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let input = CropStageCreateInput::new(crop_id, json!({ "name": "Seedling", "order": 1 }));

    let result = gw.create_crop_stage(input).unwrap();
    assert_eq!(result.name, "Seedling");
    assert_eq!(result.order, 1);
    assert_eq!(result.crop_id, crop_id);
    assert!(result.id > 0);
}

// Ruby: update_crop_stage updates an existing crop stage
#[test]
fn update_crop_stage_updates_existing_crop_stage() {
    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let created = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "Original", "order": 1 }),
        ))
        .unwrap();
    let input = CropStageUpdateInput {
        crop_stage_id: created.id,
        payload: json!({ "name": "Updated Stage", "order": 2 }),
    };

    let result = gw.update_crop_stage(created.id, input).unwrap();
    assert_eq!(result.name, "Updated Stage");
    assert_eq!(result.order, 2);
}

// Ruby: delete_crop_stage deletes an existing crop stage
#[test]
fn delete_crop_stage_deletes_existing_crop_stage() {
    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let created = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "Stage", "order": 1 }),
        ))
        .unwrap();

    gw.delete_crop_stage(created.id).unwrap();
    let count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM crop_stages WHERE id = ?1",
                params![created.id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(count, 0);
}

// Ruby: dependent: :destroy on requirements — stage delete must not violate FK
#[test]
fn delete_crop_stage_deletes_stage_with_temperature_requirement() {
    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let created = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "Stage", "order": 1 }),
        ))
        .unwrap();
    gw.create_temperature_requirement(
        created.id,
        TemperatureRequirementUpdateInput::new(
            crop_id,
            created.id,
            json!({ "base_temperature": 10.0 }),
        ),
    )
    .unwrap();

    gw.delete_crop_stage(created.id).unwrap();

    let stage_count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM crop_stages WHERE id = ?1",
                params![created.id],
                |row| row.get(0),
            )
        })
        .unwrap();
    let req_count: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM temperature_requirements WHERE crop_stage_id = ?1",
                params![created.id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(stage_count, 0);
    assert_eq!(req_count, 0);
}

// Ruby: create_temperature_requirement creates a new requirement
#[test]
fn create_temperature_requirement_creates_new_requirement() {
    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let stage = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "Stage", "order": 1 }),
        ))
        .unwrap();
    let input = TemperatureRequirementUpdateInput::new(
        crop_id,
        stage.id,
        json!({ "base_temperature": 10.0, "optimal_min": 15.0 }),
    );

    let result = gw.create_temperature_requirement(stage.id, input).unwrap();
    assert_eq!(result.crop_stage_id, stage.id);
    assert_eq!(
        result.base_temperature,
        Decimal::from_f64_retain(10.0)
    );
    assert_eq!(
        result.optimal_min,
        Decimal::from_f64_retain(15.0)
    );
}

// Ruby: list_index_for_filter owned_non_reference returns only that user's non-reference crops
#[test]
fn list_index_for_filter_owned_non_reference_returns_only_users_non_reference_crops() {
    let pool = crop_test_pool();
    let user = User::new(1, false);
    let other = User::new(2, false);
    let gw = CropSqliteGateway::new(pool.clone());

    let owned = insert_crop(&pool, user.id, "Owned", false);
    insert_crop(&pool, 0, "Ref", true);
    insert_crop(&pool, other.id, "Other", false);

    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::OwnedNonReference, user.id);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();
    assert_eq!(ids, vec![owned]);
}

// Ruby: list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id
#[test]
fn list_index_for_filter_reference_or_owned_includes_reference_and_owned_rows() {
    let pool = crop_test_pool();
    let admin = User::new(10, true);
    let other = User::new(20, false);
    let gw = CropSqliteGateway::new(pool.clone());

    let ref_id = insert_crop(&pool, 0, "Ref", true);
    let own = insert_crop(&pool, admin.id, "Admin own", false);
    let other_crop = insert_crop(&pool, other.id, "Other", false);

    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, admin.id);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();

    assert!(ids.contains(&ref_id));
    assert!(ids.contains(&own));
    assert!(!ids.contains(&other_crop));
}

// Ruby: list_by_ids returns entities in requested order for existing ids
#[test]
fn list_by_ids_returns_entities_in_requested_order() {
    let pool = crop_test_pool();
    let user = User::new(1, false);
    let gw = CropSqliteGateway::new(pool.clone());
    let crop1 = insert_crop(&pool, user.id, "Crop1", false);
    let crop2 = insert_crop(&pool, user.id, "Crop2", false);
    let ref_crop = insert_crop(&pool, 0, "Ref", true);

    let ids: Vec<i64> = PrivatePlanCropListGateway::list_by_ids(&gw, &[crop2, crop1])
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();
    assert_eq!(ids, vec![crop2, crop1]);

    let ref_only = PrivatePlanCropListGateway::list_by_ids(&gw, &[ref_crop])
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect::<Vec<_>>();
    assert_eq!(ref_only, vec![ref_crop]);
}

#[test]
fn reorder_crop_stages_updates_all_orders_in_one_transaction() {
    use agrr_domain::crop::gateways::CropStageReorderGateway;

    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let stage_a = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "A", "order": 1 }),
        ))
        .unwrap();
    let stage_b = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "B", "order": 2 }),
        ))
        .unwrap();
    let stage_c = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "C", "order": 3 }),
        ))
        .unwrap();

    let reordered = gw
        .reorder_crop_stages(
            crop_id,
            &[
                (stage_c.id, 1),
                (stage_a.id, 2),
                (stage_b.id, 3),
            ],
        )
        .unwrap();

    assert_eq!(
        reordered
            .iter()
            .map(|stage| (stage.id, stage.order))
            .collect::<Vec<_>>(),
        vec![(stage_c.id, 1), (stage_a.id, 2), (stage_b.id, 3)]
    );
}

#[test]
fn update_crop_stage_conflicting_order_returns_record_invalid() {
    use agrr_domain::shared::exceptions::RecordInvalidError;

    let pool = crop_test_pool();
    let (gw, crop_id) = seed_crop(&pool);
    let stage_a = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "A", "order": 1 }),
        ))
        .unwrap();
    let stage_b = gw
        .create_crop_stage(CropStageCreateInput::new(
            crop_id,
            json!({ "name": "B", "order": 2 }),
        ))
        .unwrap();

    let err = gw
        .update_crop_stage(
            stage_a.id,
            CropStageUpdateInput {
                crop_stage_id: stage_a.id,
                payload: json!({ "order": stage_b.order }),
            },
        )
        .unwrap_err();

    assert!(err.downcast_ref::<RecordInvalidError>().is_some());
}
