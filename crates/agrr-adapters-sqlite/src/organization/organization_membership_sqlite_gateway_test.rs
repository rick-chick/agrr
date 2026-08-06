//! Integration tests for `OrganizationMembershipSqliteGateway`.

use super::OrganizationMembershipSqliteGateway;
use super::OrganizationSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::organization::dtos::OrganizationRole;
use agrr_domain::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};

fn membership_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_mem_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "mem_gw_{}_{}.sqlite3",
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
fn create_and_update_role() {
    let pool = membership_test_pool();
    let org_gw = OrganizationSqliteGateway::new(pool.clone());
    let mem_gw = OrganizationMembershipSqliteGateway::new(pool);
    let org = org_gw.create("Team", "team", false).unwrap();
    let membership = mem_gw
        .create(org.id, 5, OrganizationRole::Member)
        .unwrap();
    assert_eq!(membership.role, OrganizationRole::Member);
    let updated = mem_gw
        .update_role(membership.id, OrganizationRole::Admin)
        .unwrap();
    assert_eq!(updated.role, OrganizationRole::Admin);
}

#[test]
fn list_for_organization_returns_all_members() {
    let pool = membership_test_pool();
    let org_gw = OrganizationSqliteGateway::new(pool.clone());
    let mem_gw = OrganizationMembershipSqliteGateway::new(pool);
    let org = org_gw.create("Team", "team", false).unwrap();
    mem_gw.create(org.id, 1, OrganizationRole::Owner).unwrap();
    mem_gw.create(org.id, 2, OrganizationRole::Member).unwrap();
    let members = mem_gw.list_for_organization(org.id).unwrap();
    assert_eq!(members.len(), 2);
}
