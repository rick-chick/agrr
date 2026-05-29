//! Ruby: `Adapters::Pest::Gateways::PestActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::attr_sql::{attr_bool, attr_str, require_str};
use crate::shared::reference_index::where_clause;
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::pest::dtos::{PestDeleteUsage, PestShowDetail};
use agrr_domain::pest::entities::{PestEntity, PestEntityAttrs};
use agrr_domain::pest::gateways::{CropPestListOrder, PestGateway, SoftDeleteWithUndoOutcome};
use agrr_domain::shared::attr::AttrMap;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;
use rusqlite::{params, types::Value};
use serde_json::json;

pub struct PestSqliteGateway {
    pool: SqlitePool,
}

impl PestSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<PestEntity> {
        let is_reference: i64 = row.get(8)?;
        PestEntity::new(PestEntityAttrs {
            id: Some(row.get(0)?),
            user_id: row.get(1)?,
            name: row.get(2)?,
            name_scientific: row.get(3)?,
            family: row.get(4)?,
            order: row.get(5)?,
            description: row.get(6)?,
            occurrence_season: row.get(7)?,
            region: row.get(9)?,
            is_reference: is_reference != 0,
            created_at: row.get(10)?,
            updated_at: row.get(11)?,
        })
        .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            e,
        ))))
    }

    const SELECT_COLS: &'static str = "id, user_id, name, name_scientific, family, \"order\", description, occurrence_season, is_reference, region, created_at, updated_at";
}

impl PestGateway for PestSqliteGateway {
    fn find_by_id(
        &self,
        pest_id: i64,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
        let sql = format!("SELECT {} FROM pests WHERE id = ?1", Self::SELECT_COLS);
        self.pool.with_read_box(|conn| {
            conn.query_row(&sql, params![pest_id], Self::row_to_entity)
        })
    }

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = require_str(&attrs, "name")?;
        let is_reference = attr_bool(&attrs, "is_reference").unwrap_or(false);
        let user_id = if is_reference {
            None
        } else {
            Some(user.id)
        };
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO pests (name, name_scientific, family, \"order\", description, occurrence_season, is_reference, user_id, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now'))",
                params![
                    name,
                    attr_str(&attrs, "name_scientific"),
                    attr_str(&attrs, "family"),
                    attr_str(&attrs, "order"),
                    attr_str(&attrs, "description"),
                    attr_str(&attrs, "occurrence_season"),
                    if is_reference { 1 } else { 0 },
                    user_id,
                    attr_str(&attrs, "region"),
                ],
            )?;
            let id = conn.last_insert_rowid();
            let sql = format!("SELECT {} FROM pests WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn update_for_user(
        &self,
        _user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets = Vec::new();
        let mut values: Vec<Value> = Vec::new();
        for key in [
            "name",
            "name_scientific",
            "family",
            "order",
            "description",
            "occurrence_season",
            "region",
        ] {
            if let Some(s) = attr_str(&attrs, key) {
                let col = if key == "order" { "\"order\"" } else { key };
                sets.push(format!("{col} = ?"));
                values.push(Value::Text(s));
            }
        }
        if let Some(b) = attr_bool(&attrs, "is_reference") {
            sets.push("is_reference = ?".into());
            values.push(Value::Integer(if b { 1 } else { 0 }));
        }
        if sets.is_empty() {
            return self.find_by_id(id);
        }
        sets.push("updated_at = datetime('now')".into());
        let sql = format!(
            "UPDATE pests SET {} WHERE id = ?",
            sets.join(", ")
        );
        values.push(Value::Integer(id));
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            let sql = format!("SELECT {} FROM pests WHERE id = ?1", Self::SELECT_COLS);
            conn.query_row(&sql, params![id], Self::row_to_entity)
        })
    }

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (where_sql, user_id) = where_clause(filter);
        let sql = format!(
            "SELECT {} FROM pests WHERE {} ORDER BY name",
            Self::SELECT_COLS,
            where_sql
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

    fn find_pest_show_detail(
        &self,
        id: i64,
    ) -> Result<PestShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        let pest = self.find_by_id(id)?;
        let temperature_profile: Option<String> = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT json_object('id', id, 'pest_id', pest_id, 'base_temperature', base_temperature, 'max_temperature', max_temperature) \
                     FROM pest_temperature_profiles WHERE pest_id = ?1",
                    params![id],
                    |row| row.get(0),
                )
            })
            .ok();
        let thermal_requirement: Option<String> = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT json_object('id', id, 'pest_id', pest_id, 'required_gdd', required_gdd) \
                     FROM pest_thermal_requirements WHERE pest_id = ?1",
                    params![id],
                    |row| row.get(0),
                )
            })
            .ok();
        let control_methods: Vec<serde_json::Value> = self
            .pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT json_object('id', id, 'method_type', method_type, 'method_name', method_name, 'description', description) \
                     FROM pest_control_methods WHERE pest_id = ?1",
                )?;
                let rows = stmt.query_map(params![id], |row| {
                    let s: String = row.get(0)?;
                    Ok(serde_json::from_str(&s).unwrap_or(json!({})))
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .unwrap_or_default();
        let associated_crops: Vec<serde_json::Value> = self
            .pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT json_object('id', c.id, 'name', c.name) FROM crops c \
                     INNER JOIN crop_pests cp ON cp.crop_id = c.id WHERE cp.pest_id = ?1",
                )?;
                let rows = stmt.query_map(params![id], |row| {
                    let s: String = row.get(0)?;
                    Ok(serde_json::from_str(&s).unwrap_or(json!({})))
                })?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .unwrap_or_default();

        Ok(PestShowDetail {
            pest,
            temperature_profile: temperature_profile
                .and_then(|s| serde_json::from_str(&s).ok()),
            thermal_requirement: thermal_requirement
                .and_then(|s| serde_json::from_str(&s).ok()),
            control_methods,
            associated_crops,
        })
    }

    fn find_delete_usage(
        &self,
        pest_id: i64,
    ) -> Result<PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        let count: i64 = self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM pesticides WHERE pest_id = ?1",
                params![pest_id],
                |row| row.get(0),
            )
        })?;
        Ok(PestDeleteUsage::new(count))
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        pest_id: i64,
        auto_hide_after: i64,
        translator: &dyn TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        let pest = self.find_by_id(pest_id)?;
        let opts = TranslateOptions::default();
        let toast = translator.t("pests.undo.toast", &opts);
        let toast = toast.replace("%{name}", &pest.name);
        match schedule_soft_delete_json(
            self.pool.clone(),
            "Pest",
            pest_id,
            user.id,
            &toast,
            auto_hide_after,
            Some(&pest.name),
        ) {
            SoftDeleteJsonOutcome::Success(undo) => {
                Ok(SoftDeleteWithUndoOutcome::Success { undo })
            }
            SoftDeleteJsonOutcome::Failure(error) => {
                Ok(SoftDeleteWithUndoOutcome::Failure(error))
            }
        }
    }

    fn find_by_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if name.is_empty() {
            return Ok(None);
        }
        let sql = format!("SELECT {} FROM pests WHERE name = ?1 AND is_reference = 0 AND user_id = ?2", Self::SELECT_COLS);
        match self.pool.with_read_box(|conn| {
            conn.query_row(&sql, params![name, user_id], Self::row_to_entity)
        }) {
            Ok(entity) => Ok(Some(entity)),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Ok(None),
            Err(err) => Err(err),
        }
    }

    fn list_pests_for_crop_filtered(
        &self,
        crop_id: i64,
        pest_ids: &[i64],
        order: CropPestListOrder,
    ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if pest_ids.is_empty() {
            return Ok(Vec::new());
        }
        let placeholders: Vec<String> = pest_ids.iter().map(|_| "?".into()).collect();
        let order_sql = match order {
            CropPestListOrder::RecentFirst => "p.created_at DESC",
            CropPestListOrder::IdAsc => "p.id ASC",
        };
        let sql = format!(
            "SELECT p.id, p.user_id, p.name, p.name_scientific, p.family, p.\"order\", p.description, p.occurrence_season, p.is_reference, p.region, p.created_at, p.updated_at \
             FROM pests p INNER JOIN crop_pests cp ON cp.pest_id = p.id \
             WHERE cp.crop_id = ? AND p.id IN ({}) ORDER BY {}",
            placeholders.join(","),
            order_sql
        );
        let mut values: Vec<Value> = vec![Value::Integer(crop_id)];
        for id in pest_ids {
            values.push(Value::Integer(*id));
        }
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(rusqlite::params_from_iter(values.iter()), Self::row_to_entity)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }
}
