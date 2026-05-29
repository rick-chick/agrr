use crate::pool::SqlitePool;
use getrandom::getrandom;
use rusqlite::params;

#[derive(Debug, Clone)]
pub struct SessionRecord {
    pub session_id: String,
    pub user_id: i64,
    pub expires_at: String,
}

pub struct SessionLookupSqliteGateway {
    pool: SqlitePool,
}

impl SessionLookupSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub fn find_active_by_session_id(
        &self,
        session_id: &str,
    ) -> Result<Option<SessionRecord>, Box<dyn std::error::Error + Send + Sync>> {
        if !Self::valid_session_id(session_id) {
            return Ok(None);
        }
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT session_id, user_id, expires_at FROM sessions \
                     WHERE session_id = ?1 AND expires_at > datetime('now')",
                )?;
                let mut rows = stmt.query(params![session_id])?;
                if let Some(row) = rows.next()? {
                    return Ok(Some(SessionRecord {
                        session_id: row.get(0)?,
                        user_id: row.get(1)?,
                        expires_at: row.get(2)?,
                    }));
                }
                Ok(None)
            })
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }

    pub fn valid_session_id(session_id: &str) -> bool {
        session_id.len() == 43
            && session_id
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
    }

    pub fn create_for_user(
        &self,
        user_id: i64,
    ) -> Result<SessionRecord, Box<dyn std::error::Error + Send + Sync>> {
        let session_id = generate_session_id();
        let expires_at = (time::OffsetDateTime::now_utc() + time::Duration::weeks(2))
            .format(&time::format_description::well_known::Iso8601::DEFAULT)
            .unwrap_or_else(|_| "2099-01-01T00:00:00Z".into());
        self.pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO sessions (session_id, user_id, expires_at, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
                params![session_id, user_id, expires_at],
            )?;
            Ok(())
        })?;
        Ok(SessionRecord {
            session_id,
            user_id,
            expires_at,
        })
    }
}

fn generate_session_id() -> String {
    let mut bytes = [0u8; 32];
    getrandom(&mut bytes).expect("random");
    base64_url_encode(&bytes)
}

fn base64_url_encode(bytes: &[u8]) -> String {
    const TABLE: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut out = String::with_capacity(43);
    let n = (bytes[0] as u32) << 16 | (bytes[1] as u32) << 8 | bytes[2] as u32;
    out.push(TABLE[((n >> 18) & 63) as usize] as char);
    out.push(TABLE[((n >> 12) & 63) as usize] as char);
    out.push(TABLE[((n >> 6) & 63) as usize] as char);
    out.push(TABLE[(n & 63) as usize] as char);
    for chunk in bytes[3..].chunks(3) {
        let b0 = chunk[0] as u32;
        let b1 = chunk.get(1).copied().unwrap_or(0) as u32;
        let b2 = chunk.get(2).copied().unwrap_or(0) as u32;
        let n = (b0 << 16) | (b1 << 8) | b2;
        out.push(TABLE[((n >> 18) & 63) as usize] as char);
        out.push(TABLE[((n >> 12) & 63) as usize] as char);
        if chunk.len() > 1 {
            out.push(TABLE[((n >> 6) & 63) as usize] as char);
        }
        if chunk.len() > 2 {
            out.push(TABLE[(n & 63) as usize] as char);
        }
    }
    out.truncate(43);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_session_id_matches_ruby_length() {
        let id = generate_session_id();
        assert!(SessionLookupSqliteGateway::valid_session_id(&id));
    }
}
