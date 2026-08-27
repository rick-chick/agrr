//! Integration tests for `UserLookupSqliteGateway`.

use super::UserLookupSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::shared::gateways::UserLookupGateway;

fn user_lookup_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_user_lookup_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "user_lookup_gw_{}_{}.sqlite3",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let pool = SqlitePool::new(path.to_str().unwrap());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              admin INTEGER,
              is_anonymous INTEGER
            );
            INSERT INTO users (id, admin, is_anonymous) VALUES (1, 0, 1);
            INSERT INTO users (id, admin, is_anonymous) VALUES (2, 1, 0);",
        )
    })
    .unwrap();
    pool
}

#[test]
fn find_reads_is_anonymous_from_db() {
    let pool = user_lookup_test_pool();
    let gateway = UserLookupSqliteGateway::new(pool);

    let anonymous = gateway.find(1);
    assert_eq!(1, anonymous.id);
    assert!(!anonymous.admin);
    assert!(anonymous.anonymous);

    let authenticated = gateway.find(2);
    assert_eq!(2, authenticated.id);
    assert!(authenticated.admin);
    assert!(!authenticated.anonymous);
}
