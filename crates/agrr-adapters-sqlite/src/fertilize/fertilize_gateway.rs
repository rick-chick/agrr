//! Ruby: `Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::attr_sql::{attr_bool, attr_f64, attr_str, require_str};
use crate::shared::reference_index::where_clause;
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
use agrr_domain::fertilize::gateways::{FertilizeGateway, SoftDeleteWithUndoOutcome};
use agrr_domain::shared::attr::AttrMap;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;
use rusqlite::{params, types::Value};

pub struct FertilizeSqliteGateway {
    pool: SqlitePool,
}

impl FertilizeSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<FertilizeEntity> {
        let is_reference: i64 = row.get(8)?;
        FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(row.get(0)?),
            user_id: row.get(1)?,
            name: row.get(2)?,
            n: row.get(3)?,
            p: row.get(4)?,
            k: row.get(5)?,
            description: row.get(6)?,
            package_size: row.get(7)?,
            region: row.get(9)?,
            is_reference: is_reference != 0,
            created_at: row.get(10)?,
            updated_at: row.get(11)?,
        })
        .map_err(|e| {
            rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl FertilizeGateway for FertilizeSqliteGateway {
    fn find_by_id(
        &self,
        fertilize_id: i64,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, user_id, name, n, p, k, description, package_size, is_reference, region, created_at, updated_at \
                 FROM fertilizes WHERE id = ?1",
                params![fertilize_id],
                Self::row_to_entity,
            )
        })
    }

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (where_sql, user_id) = where_clause(filter);
        let sql = format!(
            "SELECT id, user_id, name, n, p, k, description, package_size, is_reference, region, created_at, updated_at \
             FROM fertilizes WHERE {where_sql} AND name IS NOT NULL AND name != '' ORDER BY name"
        );
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(params![user_id], Self::row_to_entity)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = require_str(&attrs, "name")?;
        let is_reference = attr_bool(&attrs, "is_reference").unwrap_or(false);
        let user_id = if is_reference { None } else { Some(user.id) };
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO fertilizes (name, n, p, k, description, package_size, is_reference, user_id, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now'))",
                params![
                    name,
                    attr_f64(&attrs, "n"),
                    attr_f64(&attrs, "p"),
                    attr_f64(&attrs, "k"),
                    attr_str(&attrs, "description"),
                    attr_f64(&attrs, "package_size"),
                    if is_reference { 1 } else { 0 },
                    user_id,
                    attr_str(&attrs, "region"),
                ],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, user_id, name, n, p, k, description, package_size, is_reference, region, created_at, updated_at \
                 FROM fertilizes WHERE id = ?1",
                params![id],
                Self::row_to_entity,
            )
        })
    }

    fn update_for_user(
        &self,
        _user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets: Vec<String> = Vec::new();
        let mut values: Vec<Value> = Vec::new();
        if let Some(s) = attr_str(&attrs, "name") {
            sets.push("name = ?".into());
            values.push(Value::Text(s));
        }
        for (col, key) in [
            ("n = ?", "n"),
            ("p = ?", "p"),
            ("k = ?", "k"),
            ("package_size = ?", "package_size"),
        ] {
            if let Some(v) = attr_f64(&attrs, key) {
                sets.push(col.into());
                values.push(Value::Real(v));
            }
        }
        if let Some(s) = attr_str(&attrs, "description") {
            sets.push("description = ?".into());
            values.push(Value::Text(s));
        }
        if let Some(s) = attr_str(&attrs, "region") {
            sets.push("region = ?".into());
            values.push(Value::Text(s));
        }
        if sets.is_empty() {
            return self.find_by_id(id);
        }
        sets.push("updated_at = datetime('now')".into());
        let sql = format!("UPDATE fertilizes SET {} WHERE id = ?", sets.join(", "));
        values.push(Value::Integer(id));
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            conn.query_row(
                "SELECT id, user_id, name, n, p, k, description, package_size, is_reference, region, created_at, updated_at \
                 FROM fertilizes WHERE id = ?1",
                params![id],
                Self::row_to_entity,
            )
        })
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        fertilize_id: i64,
        auto_hide_after: i64,
        translator: &dyn TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        let fertilize = self.find_by_id(fertilize_id)?;
        let toast = translator.t("fertilizes.undo.toast", &TranslateOptions::default());
        match schedule_soft_delete_json(
            self.pool.clone(),
            "Fertilize",
            fertilize_id,
            user.id,
            &toast,
            auto_hide_after,
            Some(&fertilize.name),
        ) {
            SoftDeleteJsonOutcome::Success(undo) => Ok(SoftDeleteWithUndoOutcome::Success { undo }),
            SoftDeleteJsonOutcome::Failure(error) => Ok(SoftDeleteWithUndoOutcome::Failure(error)),
        }
    }

    fn find_by_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if name.is_empty() {
            return Ok(None);
        }
        match self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, user_id, name, n, p, k, description, package_size, is_reference, region, created_at, updated_at \
                 FROM fertilizes WHERE name = ?1 AND is_reference = 0 AND user_id = ?2",
                params![name, user_id],
                Self::row_to_entity,
            )
        }) {
            Ok(e) => Ok(Some(e)),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Ok(None),
            Err(err) => Err(err),
        }
    }
}
