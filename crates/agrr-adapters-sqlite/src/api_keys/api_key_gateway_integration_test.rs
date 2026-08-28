//! Integration tests for hashed API key storage and lookup.

use super::api_key_storage::{hash_api_key, api_key_prefix};
use super::UserApiKeyRotationSqliteGateway;
use crate::pool::SqlitePool;
use crate::shared::ApiKeyPrincipalSqliteGateway;
use agrr_domain::api_keys::gateways::UserApiKeyRotationGateway;
use agrr_domain::shared::gateways::ApiKeyPrincipalGateway;
use rusqlite::params;

fn api_key_test_pool() -> SqlitePool {
    let dir = std::env::temp_dir().join(format!("agrr_api_key_gw_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!(
        "api_key_gw_{}_{}.sqlite3",
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
              email TEXT,
              name TEXT,
              admin INTEGER DEFAULT 0,
              is_anonymous INTEGER DEFAULT 0,
              api_key TEXT,
              api_key_hash TEXT,
              api_key_prefix TEXT,
              api_key_scopes TEXT,
              created_at TEXT DEFAULT (datetime('now')),
              updated_at TEXT DEFAULT (datetime('now'))
            );",
        )?;
        conn.execute(
            "INSERT INTO users (id, email, name, admin, is_anonymous) VALUES (1, 'u@example.com', 'User', 0, 0)",
            [],
        )?;
        Ok(())
    })
    .unwrap();
    pool
}

#[test]
fn rotation_stores_hash_not_plaintext() {
    let pool = api_key_test_pool();
    let gateway = UserApiKeyRotationSqliteGateway::new(pool.clone());

    let output = gateway.rotate(1, true);
    assert!(output.ok);
    let key = output.api_key.expect("generated key");

    let (plaintext, stored_hash, prefix): (Option<String>, Option<String>, Option<String>) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT api_key, api_key_hash, api_key_prefix FROM users WHERE id = 1",
                [],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
        })
        .unwrap();

    assert!(plaintext.is_none() || plaintext.as_deref() == Some(""));
    assert_eq!(stored_hash.as_deref(), Some(hash_api_key(&key).as_str()));
    assert_eq!(prefix.as_deref(), Some(api_key_prefix(&key).as_str()));
}

#[test]
fn principal_resolves_by_hash_not_plaintext_column() {
    let pool = api_key_test_pool();
    let rotation = UserApiKeyRotationSqliteGateway::new(pool.clone());
    let principal_gw = ApiKeyPrincipalSqliteGateway::new(pool.clone());

    let output = rotation.rotate(1, true);
    let key = output.api_key.expect("generated key");

    pool.with_write(|conn| {
        conn.execute(
            "UPDATE users SET api_key = ?1 WHERE id = 1",
            params![key],
        )
    })
    .unwrap();

    let principal = principal_gw.principal_for_api_key(&key);
    assert!(principal.is_some(), "should resolve via hash even if legacy plaintext column is set");
    assert_eq!(principal.unwrap().id, 1);
}

#[test]
fn principal_rejects_wrong_key() {
    let pool = api_key_test_pool();
    let rotation = UserApiKeyRotationSqliteGateway::new(pool.clone());
    let principal_gw = ApiKeyPrincipalSqliteGateway::new(pool.clone());

    rotation.rotate(1, true);
    assert!(principal_gw.principal_for_api_key("not-the-key").is_none());
}

#[test]
fn lazy_rehash_migrates_legacy_plaintext_key() {
    let pool = api_key_test_pool();
    let legacy_key = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
    pool.with_write(|conn| {
        conn.execute(
            "UPDATE users SET api_key = ?1, api_key_hash = NULL, api_key_prefix = NULL WHERE id = 1",
            params![legacy_key],
        )
    })
    .unwrap();

    let principal_gw = ApiKeyPrincipalSqliteGateway::new(pool.clone());
    let principal = principal_gw.principal_for_api_key(legacy_key);
    assert!(principal.is_some());

    let (plaintext, stored_hash): (Option<String>, Option<String>) = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT api_key, api_key_hash FROM users WHERE id = 1",
                [],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
        })
        .unwrap();

    assert!(plaintext.is_none() || plaintext.as_deref() == Some(""));
    assert_eq!(stored_hash.as_deref(), Some(hash_api_key(legacy_key).as_str()));
}
