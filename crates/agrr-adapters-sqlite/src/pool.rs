//! Shared SQLite access: busy timeout (Rails `SQLITE_BUSY_TIMEOUT_MS`) and write serialization.

use rusqlite::Connection;
use std::sync::{Arc, Mutex};
use std::time::Duration;

pub const DEFAULT_BUSY_TIMEOUT_MS: u64 = 20_000;

/// Thread-safe SQLite pool with a single write mutex (Litestream single-writer compatible).
#[derive(Clone)]
pub struct SqlitePool {
    database_path: Arc<String>,
    write_lock: Arc<Mutex<()>>,
}

impl SqlitePool {
    pub fn new(database_path: impl Into<String>) -> Self {
        Self {
            database_path: Arc::new(database_path.into()),
            write_lock: Arc::new(Mutex::new(())),
        }
    }

    pub fn from_env() -> Self {
        Self::new(
            std::env::var("AGRR_SQLITE_PATH")
                .unwrap_or_else(|_| "storage/development.sqlite3".into()),
        )
    }

    pub fn database_path(&self) -> &str {
        &self.database_path
    }

    pub fn with_read<F, T>(&self, f: F) -> rusqlite::Result<T>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        let conn = self.open_connection()?;
        f(&conn)
    }

    pub fn with_write<F, T>(&self, f: F) -> rusqlite::Result<T>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        let _guard = self
            .write_lock
            .lock()
            .map_err(|_| rusqlite::Error::SqliteFailure(rusqlite::ffi::Error::new(5), None))?;
        let conn = self.open_connection()?;
        f(&conn)
    }

    /// Serialize writes and wrap `f` in `BEGIN IMMEDIATE` / `COMMIT` (or `ROLLBACK` on error).
    pub fn with_write_transaction<F, T>(&self, f: F) -> rusqlite::Result<T>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        let _guard = self
            .write_lock
            .lock()
            .map_err(|_| rusqlite::Error::SqliteFailure(rusqlite::ffi::Error::new(5), None))?;
        let conn = self.open_connection()?;
        conn.execute_batch("BEGIN IMMEDIATE")?;
        match f(&conn) {
            Ok(value) => {
                conn.execute_batch("COMMIT")?;
                Ok(value)
            }
            Err(err) => {
                let _ = conn.execute_batch("ROLLBACK");
                Err(err)
            }
        }
    }

    /// Map `with_read` to boxed errors; `QueryReturnedNoRows` becomes `RecordNotFoundError`.
    pub fn with_read_box<T, F>(&self, f: F) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        match self.with_read(f) {
            Ok(v) => Ok(v),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                Err(Box::new(agrr_domain::shared::exceptions::RecordNotFoundError)
                    as Box<dyn std::error::Error + Send + Sync>)
            }
            Err(e) => Err(Box::new(e) as Box<dyn std::error::Error + Send + Sync>),
        }
    }

    /// Map `with_write` to boxed errors; `QueryReturnedNoRows` becomes `RecordNotFoundError`.
    pub fn with_write_box<T, F>(&self, f: F) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        match self.with_write(f) {
            Ok(v) => Ok(v),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                Err(Box::new(agrr_domain::shared::exceptions::RecordNotFoundError)
                    as Box<dyn std::error::Error + Send + Sync>)
            }
            Err(e) => Err(Box::new(e) as Box<dyn std::error::Error + Send + Sync>),
        }
    }

    /// Map `with_write_transaction` to boxed errors; `QueryReturnedNoRows` becomes `RecordNotFoundError`.
    pub fn with_write_transaction_box<T, F>(
        &self,
        f: F,
    ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce(&Connection) -> rusqlite::Result<T>,
    {
        match self.with_write_transaction(f) {
            Ok(v) => Ok(v),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                Err(Box::new(agrr_domain::shared::exceptions::RecordNotFoundError)
                    as Box<dyn std::error::Error + Send + Sync>)
            }
            Err(e) => Err(Box::new(e) as Box<dyn std::error::Error + Send + Sync>),
        }
    }

    fn open_connection(&self) -> rusqlite::Result<Connection> {
        let conn = Connection::open(self.database_path.as_str())?;
        let ms = std::env::var("SQLITE_BUSY_TIMEOUT_MS")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(DEFAULT_BUSY_TIMEOUT_MS);
        conn.busy_timeout(Duration::from_millis(ms))?;
        Ok(conn)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::params;

    #[test]
    fn with_write_serializes_access() {
        let dir = std::env::temp_dir().join(format!("agrr_sqlite_pool_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test.sqlite3");
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY)")?;
            Ok(())
        })
        .unwrap();
        pool.with_read(|conn| {
            let count: i64 =
                conn.query_row("SELECT COUNT(*) FROM t", [], |row| row.get(0))?;
            assert_eq!(count, 0);
            Ok(())
        })
        .unwrap();
        pool.with_write(|conn| {
            conn.execute("INSERT INTO t DEFAULT VALUES", params![])?;
            Ok(())
        })
        .unwrap();
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn with_write_transaction_rolls_back_on_error() {
        let dir = std::env::temp_dir().join(format!(
            "agrr_sqlite_pool_txn_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test.sqlite3");
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")?;
            conn.execute("INSERT INTO t (name) VALUES ('seed')", [])?;
            Ok(())
        })
        .unwrap();

        let result = pool.with_write_transaction(|conn| {
            conn.execute("INSERT INTO t (name) VALUES ('committed')", [])?;
            conn.execute("INSERT INTO t (name) VALUES (NULL)", [])?;
            Ok::<(), rusqlite::Error>(())
        });
        assert!(result.is_err());

        let count: i64 = pool
            .with_read(|conn| conn.query_row("SELECT COUNT(*) FROM t", [], |row| row.get(0)))
            .unwrap();
        assert_eq!(count, 1);
        let _ = std::fs::remove_dir_all(dir);
    }
}
