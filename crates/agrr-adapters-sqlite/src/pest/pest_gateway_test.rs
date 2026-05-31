//! `PestSqliteGateway::create_for_user` validation (name required).

use super::pest_gateway::PestSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::pest::gateways::PestGateway;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::exceptions::RecordInvalidError;
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

fn pest_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_pest_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "pest_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE pests (
              id INTEGER PRIMARY KEY,
              user_id INTEGER,
              name TEXT NOT NULL,
              name_scientific TEXT,
              family TEXT,
              \"order\" TEXT,
              description TEXT,
              occurrence_season TEXT,
              is_reference INTEGER NOT NULL DEFAULT 0,
              region TEXT,
              created_at TEXT,
              updated_at TEXT
            );",
        )
    })
    .unwrap();
    pool
}

#[test]
fn create_for_user_persists_pest_with_name() {
    let pool = pest_test_pool();
    let user = User::new(42, false);
    let gw = PestSqliteGateway::new(pool);

    let created = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("アブラムシ")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();

    assert_eq!(created.name, "アブラムシ");
    assert_eq!(created.user_id, Some(42));
    assert!(!created.is_reference);
}

#[test]
fn create_for_user_without_name_returns_record_invalid() {
    let pool = pest_test_pool();
    let user = User::new(42, false);
    let gw = PestSqliteGateway::new(pool);

    let err = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
        )
        .unwrap_err();

    let record_invalid = err
        .downcast::<RecordInvalidError>()
        .expect("RecordInvalidError");
    assert_eq!(
        record_invalid.detail_message(),
        Some("name is required")
    );
    assert_eq!(record_invalid.to_string(), "record invalid: name is required");
}

#[test]
fn create_for_user_roundtrips_all_scalar_fields() {
    let pool = pest_test_pool();
    let user = User::new(42, false);
    let gw = PestSqliteGateway::new(pool);

    let created = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("アブラムシ")),
                ("name_scientific", AttrValue::from("Aphidoidea")),
                ("family", AttrValue::from("アブラムシ科")),
                ("order", AttrValue::from("カメムシ目")),
                ("description", AttrValue::from("葉裏に発生")),
                ("occurrence_season", AttrValue::from("春〜秋")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();

    let id = created.id;
    let loaded = gw.find_by_id(id).unwrap();
    assert_eq!(loaded.name, "アブラムシ");
    assert_eq!(loaded.name_scientific.as_deref(), Some("Aphidoidea"));
    assert_eq!(loaded.family.as_deref(), Some("アブラムシ科"));
    assert_eq!(loaded.order.as_deref(), Some("カメムシ目"));
    assert_eq!(loaded.description.as_deref(), Some("葉裏に発生"));
    assert_eq!(loaded.occurrence_season.as_deref(), Some("春〜秋"));
    assert_eq!(loaded.user_id, Some(42));
    assert!(!loaded.is_reference);
}

#[test]
fn list_index_for_filter_returns_pests_with_names() {
    let pool = pest_test_pool();
    let user = User::new(42, false);
    let gw = PestSqliteGateway::new(pool);
    gw.create_for_user(
        &user,
        attr_map_from_pairs([
            ("name", AttrValue::from("ハダニ")),
            ("is_reference", AttrValue::Bool(false)),
        ]),
    )
    .unwrap();

    let filter = agrr_domain::shared::policies::pest_policy::index_list_filter(&user);
    let rows = gw.list_index_for_filter(&filter).unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].name, "ハダニ");
}

// Ruby: pest_active_record_gateway_list_index_test.rb — list_index_for_filter owned_non_reference returns only that user's non-reference pests
#[test]
fn list_index_for_filter_owned_non_reference_returns_only_users_non_reference_pests() {
    let pool = pest_test_pool();
    let user = User::new(1, false);
    let other = User::new(2, false);
    let admin = User::new(99, true);
    let gw = PestSqliteGateway::new(pool);

    let owned = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("Mine")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    gw.create_for_user(
        &admin,
        attr_map_from_pairs([
            ("name", AttrValue::from("System ref")),
            ("is_reference", AttrValue::Bool(true)),
        ]),
    )
    .unwrap();
    gw.create_for_user(
        &other,
        attr_map_from_pairs([
            ("name", AttrValue::from("Other user")),
            ("is_reference", AttrValue::Bool(false)),
        ]),
    )
    .unwrap();

    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::OwnedNonReference, user.id);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();
    assert_eq!(ids, vec![owned.id]);
}

// Ruby: pest_active_record_gateway_list_index_test.rb — list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id
#[test]
fn list_index_for_filter_reference_or_owned_includes_reference_and_owned_rows() {
    let pool = pest_test_pool();
    let admin = User::new(10, true);
    let other = User::new(20, false);
    let gw = PestSqliteGateway::new(pool);

    let ref_row = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("Ref")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        )
        .unwrap();
    let own = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("Admin own")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    let other_pest = gw
        .create_for_user(
            &other,
            attr_map_from_pairs([
                ("name", AttrValue::from("Someone else")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();

    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, admin.id);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .map(|e| e.id)
        .collect();

    assert!(ids.contains(&ref_row.id));
    assert!(ids.contains(&own.id));
    assert!(!ids.contains(&other_pest.id));
}

#[test]
fn create_for_user_with_blank_name_returns_record_invalid() {
    let pool = pest_test_pool();
    let user = User::new(42, false);
    let gw = PestSqliteGateway::new(pool);

    let err = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap_err();

    let record_invalid = err.downcast::<RecordInvalidError>().unwrap();
    assert_eq!(
        record_invalid.detail_message(),
        Some("name is required")
    );
}
