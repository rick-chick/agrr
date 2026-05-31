//! `FertilizeSqliteGateway::update_for_user` persists numeric attrs from domain interactors.

use super::fertilize_gateway::FertilizeSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::fertilize::gateways::FertilizeGateway;
use agrr_domain::shared::attr::{attr_map_from_pairs, AttrValue};
use agrr_domain::shared::policies::fertilize_policy;
use agrr_domain::shared::user::User;
use rusqlite::params;
fn fertilize_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_fertilize_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "fertilize_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE fertilizes (
              id INTEGER PRIMARY KEY,
              user_id INTEGER,
              name TEXT NOT NULL,
              n REAL,
              p REAL,
              k REAL,
              description TEXT,
              package_size REAL,
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
fn update_for_user_persists_npk_from_string_attr_values() {
    let pool = fertilize_test_pool();
    let user = User::new(42, false);
    let gw = FertilizeSqliteGateway::new(pool.clone());

    let created = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("Urea")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    let id = created.id.expect("id");

    let updated = gw
        .update_for_user(
            &user,
            id,
            attr_map_from_pairs([
                ("name", AttrValue::from("Urea Plus")),
                ("n", AttrValue::Str("15.5".into())),
                ("p", AttrValue::Str("10".into())),
                ("k", AttrValue::Str("5.25".into())),
            ]),
        )
        .unwrap();

    assert_eq!(updated.name, "Urea Plus");
    assert_eq!(updated.n, Some(15.5));
    assert_eq!(updated.p, Some(10.0));
    assert_eq!(updated.k, Some(5.25));

    let row: (Option<f64>, Option<f64>, Option<f64>) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT n, p, k FROM fertilizes WHERE id = ?1",
                params![id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
        })
        .unwrap();
    assert_eq!(row, (Some(15.5), Some(10.0), Some(5.25)));
}

#[test]
fn create_for_user_requires_name() {
    let pool = fertilize_test_pool();
    let user = User::new(1, false);
    let gw = FertilizeSqliteGateway::new(pool);
    let err = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
        )
        .unwrap_err();
    assert!(
        err.to_string().contains("name is required"),
        "expected name is required, got {:?}",
        err
    );
}

// Ruby: fertilize_active_record_gateway_test.rb — list_index_for_filter returns only named user-owned non-reference fertilizes for regular user
#[test]
fn list_index_for_filter_returns_only_named_user_owned_non_reference_for_regular_user() {
    let pool = fertilize_test_pool();
    let user = User::new(1, false);
    let other = User::new(2, false);
    let admin_ref = User::new(99, true);
    let gw = FertilizeSqliteGateway::new(pool.clone());

    let a = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("Owned A")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    let b = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("Owned B")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    gw.create_for_user(
        &admin_ref,
        attr_map_from_pairs([
            ("name", AttrValue::from("System Ref")),
            ("is_reference", AttrValue::Bool(true)),
        ]),
    )
    .unwrap();
    gw.create_for_user(
        &other,
        attr_map_from_pairs([
            ("name", AttrValue::from("Other user row")),
            ("is_reference", AttrValue::Bool(false)),
        ]),
    )
    .unwrap();
    let blank_name = gw
        .create_for_user(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from("Temp")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        )
        .unwrap();
    let blank_id = blank_name.id.expect("id");
    pool.with_write(|conn| {
        conn.execute("UPDATE fertilizes SET name = '' WHERE id = ?1", params![blank_id])
    })
    .unwrap();

    let filter = fertilize_policy::index_list_filter(&user);
    let mut ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .filter_map(|e| e.id)
        .collect();
    ids.sort();
    let mut expected = vec![a.id.expect("a"), b.id.expect("b")];
    expected.sort();
    assert_eq!(ids, expected);
}

// Ruby: fertilize_active_record_gateway_test.rb — list_index_for_filter for admin includes reference and own user-owned rows
#[test]
fn list_index_for_filter_for_admin_includes_reference_and_own_rows() {
    let pool = fertilize_test_pool();
    let admin = User::new(10, true);
    let gw = FertilizeSqliteGateway::new(pool);

    let ref_row = gw
        .create_for_user(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("Ref row")),
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

    let filter = fertilize_policy::index_list_filter(&admin);
    let ids: Vec<i64> = gw
        .list_index_for_filter(&filter)
        .unwrap()
        .into_iter()
        .filter_map(|e| e.id)
        .collect();

    assert!(ids.contains(&ref_row.id.expect("ref")));
    assert!(ids.contains(&own.id.expect("own")));
}
