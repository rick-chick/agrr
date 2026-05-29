//! Read `users` row for `GET /api/v1/auth/me`.

use crate::pool::SqlitePool;
use rusqlite::{params, OptionalExtension};

#[derive(Debug, Clone, PartialEq)]
pub struct SessionUserRow {
    pub id: i64,
    pub name: Option<String>,
    pub email: Option<String>,
    pub avatar_url: Option<String>,
    pub admin: bool,
    pub api_key: Option<String>,
}

pub struct SessionUserReadSqliteGateway {
    pool: SqlitePool,
}

impl SessionUserReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub fn find_by_id(
        &self,
        user_id: i64,
    ) -> Result<SessionUserRow, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let row = conn
                .query_row(
                    "SELECT id, name, email, avatar_url, COALESCE(admin, 0), api_key \
                     FROM users WHERE id = ?1 LIMIT 1",
                    params![user_id],
                    |row| {
                        let admin: i64 = row.get(4)?;
                        Ok(SessionUserRow {
                            id: row.get(0)?,
                            name: row.get(1)?,
                            email: row.get(2)?,
                            avatar_url: row.get(3)?,
                            admin: admin != 0,
                            api_key: row.get(5)?,
                        })
                    },
                )
                .optional()?;
            row.ok_or(rusqlite::Error::QueryReturnedNoRows)
        })
    }
}
