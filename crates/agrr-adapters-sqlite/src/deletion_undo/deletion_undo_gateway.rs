//! `DeletionUndoGateway` — schedule + restore via SQLite snapshots.

use crate::pool::SqlitePool;
use agrr_domain::deletion_undo::entities::DeletionUndoEntity;
use agrr_domain::deletion_undo::exceptions::{
    DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use agrr_domain::deletion_undo::schedule_authorization::SchedulableRecord;
use std::collections::BTreeMap;
use time::OffsetDateTime;

pub struct DeletionUndoSqliteGateway {
    pool: SqlitePool,
}

impl DeletionUndoSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub(crate) fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

fn domain_sqlite_err<E: std::error::Error + Send + Sync + 'static>(err: E) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(err))
}

fn map_sqlite_restore_err(
    err: Box<dyn std::error::Error + Send + Sync>,
) -> Box<dyn std::error::Error + Send + Sync> {
    if let Some(sqlite) = err.downcast_ref::<rusqlite::Error>() {
        if let rusqlite::Error::ToSqlConversionFailure(inner) = sqlite {
            if inner.is::<DeletionUndoNotFoundError>() {
                return Box::new(DeletionUndoNotFoundError);
            }
            if let Some(conflict) = inner.downcast_ref::<DeletionUndoRestoreConflictError>() {
                return Box::new(DeletionUndoRestoreConflictError(conflict.0.clone()));
            }
        }
    }
    err
}

fn parse_rfc3339(s: &str) -> OffsetDateTime {
    OffsetDateTime::parse(s, &time::format_description::well_known::Iso8601::DEFAULT)
        .unwrap_or_else(|_| OffsetDateTime::now_utc())
}

impl DeletionUndoGateway for DeletionUndoSqliteGateway {
    fn find_by_token(
        &self,
        undo_token: &str,
    ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, expires_at, state, metadata FROM deletion_undo_events WHERE id = ?1",
                rusqlite::params![undo_token],
                |row| {
                    let metadata_json: String = row.get(3)?;
                    let metadata: BTreeMap<String, String> =
                        serde_json::from_str(&metadata_json).unwrap_or_default();
                    Ok(DeletionUndoEntity::new(
                        row.get::<_, String>(0)?,
                        parse_rfc3339(&row.get::<_, String>(1)?),
                        row.get::<_, String>(2)?,
                        metadata,
                    ))
                },
            )
        })
    }

    fn expire_if_needed(
        &self,
        event_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _ = self
            .find_by_token(event_id)
            .map_err(|_| Box::new(DeletionUndoNotFoundError) as Box<dyn std::error::Error + Send + Sync>)?;
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE deletion_undo_events SET state = 'expired', finalized_at = datetime('now'), updated_at = datetime('now') \
                 WHERE id = ?1 AND state = 'scheduled' AND expires_at <= datetime('now')",
                rusqlite::params![event_id],
            )?;
            Ok(())
        })
    }

    fn perform_restore(
        &self,
        event_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_write_box(|conn| {
                let (snapshot_json, state): (String, String) = conn
                    .query_row(
                        "SELECT snapshot, state FROM deletion_undo_events WHERE id = ?1",
                        rusqlite::params![event_id],
                        |row| {
                            let snapshot = match row.get::<_, rusqlite::types::Value>(0)? {
                                rusqlite::types::Value::Text(s) => s,
                                rusqlite::types::Value::Blob(b) => {
                                    String::from_utf8_lossy(&b).into_owned()
                                }
                                rusqlite::types::Value::Null => String::new(),
                                other => format!("{other:?}"),
                            };
                            Ok((snapshot, row.get(1)?))
                        },
                    )
                    .map_err(|_| domain_sqlite_err(DeletionUndoNotFoundError))?;

                if state != "scheduled" {
                    return Err(domain_sqlite_err(DeletionUndoRestoreConflictError(
                        "undo event is not scheduled".into(),
                    )));
                }

                let snapshot: serde_json::Value = serde_json::from_str(&snapshot_json)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;

                super::restore::restore_snapshot(conn, &snapshot).map_err(|e| {
                    if let rusqlite::Error::SqliteFailure(code, _) = &e {
                        if code.code == rusqlite::ErrorCode::ConstraintViolation {
                            return domain_sqlite_err(DeletionUndoRestoreConflictError(
                                e.to_string(),
                            ));
                        }
                    }
                    e
                })?;

                conn.execute(
                    "UPDATE deletion_undo_events SET state = 'restored', finalized_at = datetime('now'), updated_at = datetime('now') \
                     WHERE id = ?1",
                    rusqlite::params![event_id],
                )?;
                Ok(())
            })
            .map_err(map_sqlite_restore_err)
    }

    fn mark_failed(
        &self,
        event_id: &str,
        error_message: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE deletion_undo_events SET state = 'failed', metadata = json_set(COALESCE(metadata, '{}'), '$.error', ?2), \
                 finalized_at = datetime('now'), updated_at = datetime('now') WHERE id = ?1",
                rusqlite::params![event_id, error_message],
            )?;
            Ok(())
        })
    }

    fn find_schedulable_record(
        &self,
        resource_type: &str,
        resource_id: i64,
    ) -> Result<SchedulableRecord, Box<dyn std::error::Error + Send + Sync>> {
        let table = crate::deletion_undo::schedule::master_table_name(resource_type)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
        let sql = format!("SELECT is_reference, user_id FROM {table} WHERE id = ?1");
        self.pool.with_read_box(|conn| {
            conn.query_row(&sql, rusqlite::params![resource_id], |row| {
                let is_reference: i64 = row.get(0)?;
                let user_id: Option<i64> = row.get(1)?;
                Ok(SchedulableRecord {
                    type_name: resource_type.to_string(),
                    is_reference: is_reference != 0,
                    user_id,
                    farm_user_id: None,
                    plan_type_private: None,
                    plan_user_id: None,
                })
            })
        })
    }

    fn schedule(
        &self,
        resource_type: &str,
        resource_id: i64,
        actor_id: Option<i64>,
        toast_message: Option<&str>,
        auto_hide_after: Option<i64>,
        _metadata: &BTreeMap<String, String>,
        _validate_before_schedule: bool,
    ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
        let scheduled = crate::deletion_undo::schedule::schedule_destroy(
            &self.pool,
            resource_type,
            resource_id,
            actor_id.unwrap_or(0),
            toast_message.unwrap_or(""),
            auto_hide_after.unwrap_or(5),
            BTreeMap::new(),
        )?;
        let mut meta = BTreeMap::new();
        if let Some(obj) = scheduled.metadata.as_object() {
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    meta.insert(k.clone(), s.to_string());
                }
            }
        }
        Ok(DeletionUndoEntity::new(
            scheduled.undo_token,
            parse_rfc3339(&scheduled.expires_at),
            "scheduled",
            meta,
        ))
    }
}
