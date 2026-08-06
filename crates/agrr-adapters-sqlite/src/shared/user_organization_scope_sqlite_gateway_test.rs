//! Integration tests for `UserOrganizationScopeSqliteGateway`.

use super::UserOrganizationScopeSqliteGateway;
use crate::organization::OrganizationMembershipSqliteGateway;
use crate::organization::OrganizationSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::organization::dtos::OrganizationRole;
use agrr_domain::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use agrr_domain::shared::gateways::UserOrganizationScopeGateway;

fn scope_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_scope_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "scope_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE organizations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              slug TEXT NOT NULL UNIQUE,
              is_personal INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE organization_memberships (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              organization_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              role TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(organization_id, user_id)
            );",
        )
    })
    .unwrap();
    pool
}

#[test]
fn organization_ids_for_user_returns_all_memberships() {
    let pool = scope_test_pool();
    let org_gw = OrganizationSqliteGateway::new(pool.clone());
    let mem_gw = OrganizationMembershipSqliteGateway::new(pool.clone());
    let scope_gw = UserOrganizationScopeSqliteGateway::new(pool);

    let org_a = org_gw
        .create("Team A", "team-a", false)
        .expect("create org a");
    let org_b = org_gw
        .create("Team B", "team-b", false)
        .expect("create org b");
    mem_gw
        .create(org_a.id, 42, OrganizationRole::Owner)
        .expect("membership a");
    mem_gw
        .create(org_b.id, 42, OrganizationRole::Member)
        .expect("membership b");

    let mut org_ids = scope_gw.organization_ids_for_user(42).expect("scope ids");
    org_ids.sort_unstable();
    assert_eq!(vec![org_a.id, org_b.id], org_ids);
}

#[test]
fn organization_ids_for_user_returns_empty_when_no_memberships() {
    let pool = scope_test_pool();
    let scope_gw = UserOrganizationScopeSqliteGateway::new(pool);
    assert!(scope_gw.organization_ids_for_user(99).unwrap().is_empty());
}
