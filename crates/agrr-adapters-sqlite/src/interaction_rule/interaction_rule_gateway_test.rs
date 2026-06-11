//! Parity: `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb`

use super::interaction_rule_gateway::InteractionRuleSqliteGateway;
use super::interaction_rule_plan_read_gateway::InteractionRulePlanReadSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::gateways::InteractionRulePlanReadGateway;
use agrr_domain::interaction_rule::gateways::{
    InteractionRuleGateway, SoftDeleteWithUndoOutcome,
};
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use agrr_domain::shared::policies::interaction_rule_policy;
use agrr_domain::shared::user::User;
use rusqlite::params;

fn interaction_rule_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_ir_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "ir_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE interaction_rules (
              id INTEGER PRIMARY KEY, user_id INTEGER, rule_type TEXT NOT NULL,
              source_group TEXT NOT NULL, target_group TEXT NOT NULL, impact_ratio REAL NOT NULL,
              is_directional INTEGER NOT NULL DEFAULT 1, description TEXT, region TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE farms (
              id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT NOT NULL,
              latitude REAL, longitude REAL, region TEXT, is_reference INTEGER NOT NULL DEFAULT 0,
              created_at TEXT, updated_at TEXT, weather_data_status TEXT,
              weather_data_fetched_years INTEGER, weather_data_total_years INTEGER,
              weather_data_last_error TEXT, weather_location_id INTEGER,
              last_broadcast_at REAL
            );
            CREATE TABLE cultivation_plans (
              id INTEGER PRIMARY KEY, farm_id INTEGER NOT NULL, user_id INTEGER,
              total_area REAL, plan_type TEXT, plan_year INTEGER, plan_name TEXT,
              planning_start_date TEXT, planning_end_date TEXT, status TEXT,
              created_at TEXT, updated_at TEXT
            );
            CREATE TABLE deletion_undo_events (
              id TEXT PRIMARY KEY, resource_type TEXT NOT NULL, resource_id TEXT NOT NULL,
              snapshot TEXT NOT NULL DEFAULT '{}', metadata TEXT NOT NULL DEFAULT '{}',
              deleted_by_id INTEGER, expires_at TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'scheduled',
              restored_at TEXT, finalized_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            );",
        )
    })
    .unwrap();
    pool
}

fn insert_reference_rule(pool: &SqlitePool, rule_type: &str, region: &str) -> i64 {
    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO interaction_rules (rule_type, source_group, target_group, impact_ratio, is_directional, region, is_reference, created_at, updated_at) \
             VALUES (?1, 'ナス科', 'ナス科', 0.7, 1, ?2, 1, datetime('now'), datetime('now'))",
            params![rule_type, region],
        )?;
        Ok(conn.last_insert_rowid())
    })
    .unwrap()
}

// Ruby: should find by id and return entity
#[test]
fn find_by_id_returns_entity() {
    let pool = interaction_rule_test_pool();
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let rule_id = insert_reference_rule(&pool, "continuous_cultivation", "jp");

    let entity = gw.find_by_id(rule_id).unwrap();
    assert_eq!(entity.id, Some(rule_id));
    assert_eq!(entity.rule_type, "continuous_cultivation");
    assert_eq!(entity.region.as_deref(), Some("jp"));
}

// Ruby: should raise when not found
#[test]
fn find_by_id_raises_when_not_found() {
    let pool = interaction_rule_test_pool();
    let gw = InteractionRuleSqliteGateway::new(pool);
    let err = gw.find_by_id(9999).unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
}

// Ruby: should create and return entity
#[test]
fn create_for_user_persists_entity() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool);

    let entity = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        )
        .unwrap();

    assert_eq!(entity.rule_type, "continuous_cultivation");
    assert_eq!(entity.region.as_deref(), Some("us"));
    assert!(entity.is_reference);
}

// Ruby: should raise when create fails validation - invalid region
#[test]
fn create_for_user_raises_record_invalid_on_invalid_region() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool);

    let err = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("invalid")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        )
        .unwrap_err();
    assert!(err.downcast_ref::<RecordInvalidError>().is_some());
}

// Ruby: should update and return entity
#[test]
fn update_for_user_persists_changes() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let rule_id = insert_reference_rule(&pool, "continuous_cultivation", "jp");

    let entity = gw
        .update_for_user(
            &admin,
            rule_id,
            attr_map_from_pairs([("region", AttrValue::from("us"))]),
        )
        .unwrap();

    assert_eq!(entity.id, Some(rule_id));
    assert_eq!(entity.region.as_deref(), Some("us"));
    assert_eq!(entity.rule_type, "continuous_cultivation");
}

// Ruby: should raise when update fails validation - invalid region
#[test]
fn update_for_user_raises_record_invalid_on_invalid_region() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let rule_id = insert_reference_rule(&pool, "continuous_cultivation", "jp");

    let err = gw
        .update_for_user(
            &admin,
            rule_id,
            attr_map_from_pairs([("region", AttrValue::from("invalid"))]),
        )
        .unwrap_err();
    assert!(err.downcast_ref::<RecordInvalidError>().is_some());
}

// Ruby: should list all records and return entities
#[test]
fn list_index_for_filter_for_admin_returns_all_reference_rows() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let record1 = insert_reference_rule(&pool, "continuous_cultivation", "jp");
    let record2 = insert_reference_rule(&pool, "continuous_cultivation", "us");

    let filter = interaction_rule_policy::index_list_filter(&admin);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .filter_map(|e| e.id)
        .collect();

    assert_eq!(ids.len(), 2);
    assert!(ids.contains(&record1));
    assert!(ids.contains(&record2));
}

// Ruby: should list with scope and return entities
#[test]
fn list_index_for_filter_can_be_scoped_to_region_in_test() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let record1 = insert_reference_rule(&pool, "continuous_cultivation", "jp");
    insert_reference_rule(&pool, "continuous_cultivation", "us");

    let filter = interaction_rule_policy::index_list_filter(&admin);
    let jp_entities: Vec<_> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .filter(|e| e.region.as_deref() == Some("jp"))
        .collect();

    assert_eq!(jp_entities.len(), 1);
    assert_eq!(jp_entities[0].id, Some(record1));
}

// Ruby: list_index_for_filter returns scoped entities for non-admin
#[test]
fn list_index_for_filter_returns_scoped_entities_for_non_admin() {
    let pool = interaction_rule_test_pool();
    let user = User::new(2, false);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    insert_reference_rule(&pool, "continuous_cultivation", "jp");
    let my_rule = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("jp")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();

    let filter = interaction_rule_policy::index_list_filter(&user);
    let entities = gw.list_index_for_filter(&filter).unwrap();
    assert_eq!(entities.len(), 1);
    assert_eq!(entities[0].id, my_rule.id);
}

// Ruby: list_index_for_filter for admin includes reference and own rows
#[test]
fn list_index_for_filter_for_admin_includes_reference_and_own_rows() {
    let pool = interaction_rule_test_pool();
    let admin = User::new(1, true);
    let other = User::new(2, false);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let ref_id = insert_reference_rule(&pool, "continuous_cultivation", "jp");
    let own = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("jp")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    gw.create_for_user(
        &other,
        attr_map_from_pairs([
            ("rule_type", AttrValue::from("continuous_cultivation")),
            ("source_group", AttrValue::from("ナス科")),
            ("target_group", AttrValue::from("ナス科")),
            ("impact_ratio", AttrValue::Str("0.7".into())),
            ("region", AttrValue::from("jp")),
            ("is_reference", AttrValue::Bool(false)),
        ]),
    )
    .unwrap();

    let filter = interaction_rule_policy::index_list_filter(&admin);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .filter_map(|e| e.id)
        .collect();

    assert!(ids.contains(&ref_id));
    assert!(ids.contains(&own.id.unwrap()));
}

// Ruby: list_by_cultivation_plan_id returns entities for plan farm region
#[test]
fn list_by_cultivation_plan_id_returns_entities_for_plan_farm_region() {
    let pool = interaction_rule_test_pool();
    let user = User::new(1, false);
    let gw = InteractionRulePlanReadSqliteGateway::new(pool.clone());
    let farm_id = pool
        .with_write(|conn| {
            conn.execute(
                "INSERT INTO farms (user_id, name, latitude, longitude, region, is_reference, weather_data_status, weather_data_fetched_years, weather_data_total_years, created_at, updated_at) \
                 VALUES (?1, 'Farm', 35.0, 139.0, 'jp', 0, 'pending', 0, 0, datetime('now'), datetime('now'))",
                params![user.id],
            )?;
            Ok(conn.last_insert_rowid())
        })
        .unwrap();
    let plan_id = pool
        .with_write(|conn| {
            conn.execute(
                "INSERT INTO cultivation_plans (farm_id, user_id, created_at, updated_at) \
                 VALUES (?1, ?2, datetime('now'), datetime('now'))",
                params![farm_id, user.id],
            )?;
            Ok(conn.last_insert_rowid())
        })
        .unwrap();
    let ref_rule = insert_reference_rule(&pool, "continuous_cultivation", "jp");
    insert_reference_rule(&pool, "continuous_cultivation", "us");

    let entities = gw.list_by_cultivation_plan_id(plan_id).unwrap();
    assert_eq!(entities.len(), 1);
    assert_eq!(entities[0].id, Some(ref_rule));
}

struct StubTranslator;

impl TranslatorPort for StubTranslator {
    fn translate(&self, key: &str, _: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(
        &self,
        _: time::Date,
        _: Option<&str>,
        _: &TranslateOptions,
    ) -> String {
        String::new()
    }
}

// DELETE JSON must match Rails `DeletionUndoResponse` (flat `undo_path` for Angular UndoToastService).
#[test]
fn soft_delete_with_undo_returns_flat_undo_path_and_restores_row() {
    use crate::deletion_undo::DeletionUndoSqliteGateway;
    use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;

    let pool = interaction_rule_test_pool();
    let user = User::new(42, false);
    let gw = InteractionRuleSqliteGateway::new(pool.clone());
    let created = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("source_group", AttrValue::from("ナス科")),
                ("target_group", AttrValue::from("ナス科")),
                ("impact_ratio", AttrValue::Str("0.7".into())),
                ("region", AttrValue::from("jp")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    let rule_id = created.id.expect("id");

    let SoftDeleteWithUndoOutcome::Success(success) =
        gw.soft_delete_with_undo(&user, rule_id, 5000, &StubTranslator)
            .expect("soft delete")
    else {
        panic!("expected soft delete success");
    };
    let undo = success.undo;
    let undo_token = undo
        .get("undo_token")
        .and_then(|v| v.as_str())
        .expect("undo_token");
    let undo_path = undo.get("undo_path").and_then(|v| v.as_str()).expect("undo_path");
    assert_eq!(
        undo_path,
        format!("/undo_deletion?undo_token={undo_token}")
    );
    assert!(undo.get("toast_message").is_some());

    let count_after_delete: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM interaction_rules WHERE id = ?1",
                params![rule_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(count_after_delete, 0);

    DeletionUndoSqliteGateway::new(pool.clone())
        .perform_restore(undo_token)
        .expect("restore");

    let count_after_restore: i64 = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM interaction_rules WHERE id = ?1",
                params![rule_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(count_after_restore, 1);
}
