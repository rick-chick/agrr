//! Ruby: `Adapters::Pesticide::Gateways::PesticideActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::attr_sql::{attr_bool, attr_i64, attr_str, require_str};
use crate::shared::reference_index::where_clause;
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::pesticide::dtos::{
    PesticideApplicationDetailSnapshot, PesticideUsageConstraintSnapshot,
};
use agrr_domain::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
use agrr_domain::pesticide::gateways::{
    PesticideGateway, PesticideShowDetailGatewayDto, SoftDeleteWithUndoOutcome,
};
use agrr_domain::shared::attr::AttrMap;
use agrr_domain::shared::ports::translator_port::TranslateOptions;
use agrr_domain::shared::ports::TranslatorPort;
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;
use rusqlite::{params, types::Value};

pub struct PesticideSqliteGateway {
    pool: SqlitePool,
}

impl PesticideSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    const SELECT_COLS: &'static str =
        "id, user_id, name, active_ingredient, description, crop_id, pest_id, is_reference, region, created_at, updated_at";

    fn row_to_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<PesticideEntity> {
        let is_reference: i64 = row.get(7)?;
        PesticideEntity::new(PesticideEntityAttrs {
            id: row.get(0)?,
            user_id: row.get(1)?,
            name: row.get(2)?,
            active_ingredient: row.get(3)?,
            description: row.get(4)?,
            crop_id: Some(row.get(5)?),
            pest_id: Some(row.get(6)?),
            region: row.get(8)?,
            is_reference: is_reference != 0,
            created_at: row.get(9)?,
            updated_at: row.get(10)?,
        })
        .map_err(|e| {
            rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl PesticideGateway for PesticideSqliteGateway {
    fn find_by_id(
        &self,
        pesticide_id: i64,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!(
            "SELECT {} FROM pesticides WHERE id = ?1",
            Self::SELECT_COLS
        );
        self.pool.with_read_box(|conn| conn.query_row(&sql, params![pesticide_id], Self::row_to_entity))
    }

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (where_sql, user_id) = where_clause(filter);
        let sql = format!(
            "SELECT {} FROM pesticides WHERE {where_sql} ORDER BY name",
            Self::SELECT_COLS
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

    fn find_pesticide_show_detail(
        &self,
        id: i64,
    ) -> Result<PesticideShowDetailGatewayDto, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let sql = format!(
                "SELECT p.id, p.user_id, p.name, p.active_ingredient, p.description, p.crop_id, p.pest_id, \
                 p.is_reference, p.region, p.created_at, p.updated_at, c.name AS crop_name, pe.name AS pest_name \
                 FROM pesticides p \
                 LEFT JOIN crops c ON c.id = p.crop_id \
                 LEFT JOIN pests pe ON pe.id = p.pest_id \
                 WHERE p.id = ?1"
            );
            let (pesticide, crop_name, pest_name) = conn.query_row(&sql, params![id], |row| {
                let is_reference: i64 = row.get(7)?;
                let entity = PesticideEntity::new(PesticideEntityAttrs {
                    id: row.get(0)?,
                    user_id: row.get(1)?,
                    name: row.get(2)?,
                    active_ingredient: row.get(3)?,
                    description: row.get(4)?,
                    crop_id: Some(row.get(5)?),
                    pest_id: Some(row.get(6)?),
                    region: row.get(8)?,
                    is_reference: is_reference != 0,
                    created_at: row.get(9)?,
                    updated_at: row.get(10)?,
                })
                .map_err(|e| {
                    rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                        std::io::ErrorKind::InvalidData,
                        e,
                    )))
                })?;
                Ok((entity, row.get::<_, Option<String>>(11)?, row.get::<_, Option<String>>(12)?))
            })?;

            let usage_constraint_snapshot = conn
                .query_row(
                    "SELECT min_temperature, max_temperature, max_wind_speed_m_s, max_application_count, harvest_interval_days, other_constraints \
                     FROM pesticide_usage_constraints WHERE pesticide_id = ?1",
                    params![id],
                    |row| {
                        Ok(PesticideUsageConstraintSnapshot {
                            min_temperature: row.get(0)?,
                            max_temperature: row.get(1)?,
                            max_wind_speed_m_s: row.get(2)?,
                            max_application_count: row.get(3)?,
                            harvest_interval_days: row.get(4)?,
                            other_constraints: row.get(5)?,
                        })
                    },
                )
                .ok();

            let application_detail_snapshot = conn
                .query_row(
                    "SELECT dilution_ratio, amount_per_m2, amount_unit, application_method \
                     FROM pesticide_application_details WHERE pesticide_id = ?1",
                    params![id],
                    |row| {
                        Ok(PesticideApplicationDetailSnapshot {
                            dilution_ratio: row.get(0)?,
                            amount_per_m2: row.get(1)?,
                            amount_unit: row.get(2)?,
                            application_method: row.get(3)?,
                        })
                    },
                )
                .ok();

            Ok(PesticideShowDetailGatewayDto {
                pesticide,
                crop_name,
                pest_name,
                usage_constraint_snapshot,
                application_detail_snapshot,
            })
        })
    }

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = require_str(&attrs, "name")?;
        let crop_id = attr_i64(&attrs, "crop_id").ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidInput, "crop_id required")
        })?;
        let pest_id = attr_i64(&attrs, "pest_id").ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidInput, "pest_id required")
        })?;
        let is_reference = attr_bool(&attrs, "is_reference").unwrap_or(false);
        let user_id = if is_reference { None } else { Some(user.id) };
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO pesticides (name, active_ingredient, description, crop_id, pest_id, is_reference, user_id, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, datetime('now'), datetime('now'))",
                params![
                    name,
                    attr_str(&attrs, "active_ingredient"),
                    attr_str(&attrs, "description"),
                    crop_id,
                    pest_id,
                    if is_reference { 1 } else { 0 },
                    user_id,
                    attr_str(&attrs, "region"),
                ],
            )?;
            let id = conn.last_insert_rowid();
            let sql = format!("SELECT {} FROM pesticides WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn update_for_user(
        &self,
        _user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets = Vec::new();
        let mut values: Vec<Value> = Vec::new();
        for key in [
            "name",
            "active_ingredient",
            "description",
            "region",
        ] {
            if let Some(s) = attr_str(&attrs, key) {
                sets.push(format!("{key} = ?"));
                values.push(Value::Text(s));
            }
        }
        if let Some(crop_id) = attr_i64(&attrs, "crop_id") {
            sets.push("crop_id = ?".into());
            values.push(Value::Integer(crop_id));
        }
        if let Some(pest_id) = attr_i64(&attrs, "pest_id") {
            sets.push("pest_id = ?".into());
            values.push(Value::Integer(pest_id));
        }
        if let Some(b) = attr_bool(&attrs, "is_reference") {
            sets.push("is_reference = ?".into());
            values.push(Value::Integer(if b { 1 } else { 0 }));
        }
        if sets.is_empty() {
            return self.find_by_id(id);
        }
        sets.push("updated_at = datetime('now')".into());
        let sql = format!("UPDATE pesticides SET {} WHERE id = ?", sets.join(", "));
        values.push(Value::Integer(id));
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            let sql = format!("SELECT {} FROM pesticides WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        pesticide_id: i64,
        auto_hide_after: i64,
        translator: &dyn TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        let pesticide = self.find_by_id(pesticide_id)?;
        let mut opts = TranslateOptions::new();
        opts.insert("name".into(), pesticide.name.clone());
        let toast = translator.t("pesticides.undo.toast", &opts);
        match schedule_soft_delete_json(
            self.pool.clone(),
            "Pesticide",
            pesticide_id,
            user.id,
            &toast,
            auto_hide_after,
            Some(&pesticide.name),
        ) {
            SoftDeleteJsonOutcome::Success(undo) => Ok(SoftDeleteWithUndoOutcome::Success { undo }),
            SoftDeleteJsonOutcome::Failure(error) => Ok(SoftDeleteWithUndoOutcome::Failure(error)),
        }
    }

    fn list_by_crop_id_for_filter(
        &self,
        crop_id: i64,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (where_sql, user_id) = where_clause(filter);
        let sql = format!(
            "SELECT {} FROM pesticides WHERE crop_id = ?1 AND {where_sql} ORDER BY created_at DESC",
            Self::SELECT_COLS
        );
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(params![crop_id, user_id], Self::row_to_entity)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }
}
