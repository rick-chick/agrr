//! One-time migration of legacy plaintext `users.api_key` values to hashed storage.

use super::api_key_storage::{api_key_prefix, hash_api_key};
use crate::pool::SqlitePool;
use rusqlite::params;

/// Rehash all users that still have a plaintext `api_key` column set.
pub fn backfill_plaintext_api_keys(pool: &SqlitePool) -> Result<usize, rusqlite::Error> {
    let legacy_rows: Vec<(i64, String)> = pool.with_read(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, api_key FROM users
             WHERE api_key IS NOT NULL AND TRIM(api_key) != ''
               AND (api_key_hash IS NULL OR TRIM(api_key_hash) = '')",
        )?;
        let rows = stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    })?;

    let mut migrated = 0usize;
    for (user_id, api_key) in legacy_rows {
        let key_hash = hash_api_key(&api_key);
        let prefix = api_key_prefix(&api_key);
        let updated = pool.with_write(|conn| {
            conn.execute(
                "UPDATE users SET api_key = NULL, api_key_hash = ?1, api_key_prefix = ?2, \
                 updated_at = datetime('now') WHERE id = ?3",
                params![key_hash, prefix, user_id],
            )
        })?;
        if updated > 0 {
            migrated += 1;
        }
    }
    Ok(migrated)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn backfill_test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_api_key_backfill_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "api_key_backfill_{}_{}.sqlite3",
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
                  api_key TEXT,
                  api_key_hash TEXT,
                  api_key_prefix TEXT,
                  updated_at TEXT
                );",
            )?;
            conn.execute(
                "INSERT INTO users (id, api_key) VALUES (1, ?1)",
                params!["abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"],
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn backfill_hashes_legacy_plaintext_and_clears_column() {
        let pool = backfill_test_pool();
        let migrated = backfill_plaintext_api_keys(&pool).expect("backfill");
        assert_eq!(migrated, 1);

        let (plaintext, hash): (Option<String>, Option<String>) = pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT api_key, api_key_hash FROM users WHERE id = 1",
                    [],
                    |row| Ok((row.get(0)?, row.get(1)?)),
                )
            })
            .unwrap();

        assert!(plaintext.is_none() || plaintext.as_deref() == Some(""));
        assert!(hash.is_some());
    }
}
