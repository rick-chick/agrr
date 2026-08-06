//! Integration tests for `OrganizationSqliteGateway`.

use super::OrganizationSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::organization::dtos::OrganizationRole;
use agrr_domain::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use super::OrganizationMembershipSqliteGateway;

fn organization_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_org_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "org_gw_{}_{}.sqlite3",
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
fn create_and_find_organization() {
    let pool = organization_test_pool();
    let gw = OrganizationSqliteGateway::new(pool);
    let created = gw.create("Acme", "acme", false).unwrap();
    assert_eq!(created.name, "Acme");
    assert_eq!(created.slug, "acme");
    let found = gw.find_by_id(created.id).unwrap();
    assert_eq!(found.slug, "acme");
}

#[test]
fn list_for_user_returns_member_orgs_only() {
    let pool = organization_test_pool();
    let org_gw = OrganizationSqliteGateway::new(pool.clone());
    let mem_gw = OrganizationMembershipSqliteGateway::new(pool);
    let org_a = org_gw.create("A", "org-a", false).unwrap();
    let org_b = org_gw.create("B", "org-b", false).unwrap();
    mem_gw
        .create(org_a.id, 1, OrganizationRole::Owner)
        .unwrap();
    mem_gw
        .create(org_b.id, 2, OrganizationRole::Owner)
        .unwrap();

    let list = org_gw.list_for_user(1).unwrap();
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].slug, "org-a");
}

#[test]
fn delete_removes_org_and_memberships() {
    let pool = organization_test_pool();
    let org_gw = OrganizationSqliteGateway::new(pool.clone());
    let mem_gw = OrganizationMembershipSqliteGateway::new(pool);
    let org = org_gw.create("Del", "del", false).unwrap();
    mem_gw
        .create(org.id, 1, OrganizationRole::Owner)
        .unwrap();
    org_gw.delete(org.id).unwrap();
    assert!(org_gw.find_by_id(org.id).is_err());
    assert!(mem_gw.find_membership(org.id, 1).unwrap().is_none());
}
