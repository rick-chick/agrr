//! Ruby: `Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::attr_sql::{attr_bool, attr_f64, attr_str, require_str};
use crate::shared::reference_index::where_clause;
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
use agrr_domain::interaction_rule::gateways::{
    InteractionRuleGateway, SoftDeleteWithUndoOutcome, SoftDeleteWithUndoSuccess,
};
use agrr_domain::shared::attr::AttrMap;
use agrr_domain::shared::exceptions::RecordInvalidError;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;
use rusqlite::{params, types::Value};

pub struct InteractionRuleSqliteGateway {
    pool: SqlitePool,
}

const VALID_REGIONS: [&str; 3] = ["jp", "us", "in"];

fn validate_region_attr(attrs: &AttrMap) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Some(region) = attr_str(attrs, "region") {
        if !VALID_REGIONS.contains(&region.as_str()) {
            return Err(Box::new(RecordInvalidError::new(
                Some("region must be one of jp, us, in".into()),
                None,
            )));
        }
    }
    Ok(())
}

impl InteractionRuleSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub(crate) fn row_to_entity(row: &rusqlite::Row<'_>) -> rusqlite::Result<InteractionRuleEntity> {
        let is_reference: i64 = row.get(9)?;
        let is_directional: i64 = row.get(6)?;
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            id: Some(row.get(0)?),
            user_id: row.get(1)?,
            rule_type: row.get(2)?,
            source_group: row.get(3)?,
            target_group: row.get(4)?,
            impact_ratio: row.get(5)?,
            is_directional: Some(is_directional != 0),
            description: row.get(7)?,
            region: row.get(8)?,
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

impl InteractionRuleGateway for InteractionRuleSqliteGateway {
    fn find_by_id(
        &self,
        rule_id: i64,
    ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, is_directional, description, region, is_reference, created_at, updated_at \
                 FROM interaction_rules WHERE id = ?1",
                params![rule_id],
                Self::row_to_entity,
            )
        })
    }

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (where_sql, user_id) = where_clause(filter);
        let sql = format!(
            "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, is_directional, description, region, is_reference, created_at, updated_at \
             FROM interaction_rules WHERE {where_sql} ORDER BY rule_type, source_group"
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
    ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
        let rule_type = require_str(&attrs, "rule_type")?;
        let source_group = require_str(&attrs, "source_group")?;
        let target_group = require_str(&attrs, "target_group")?;
        let impact_ratio = attr_f64(&attrs, "impact_ratio").unwrap_or(1.0);
        let is_reference = attr_bool(&attrs, "is_reference").unwrap_or(false);
        let is_directional = attr_bool(&attrs, "is_directional").unwrap_or(true);
        validate_region_attr(&attrs)?;
        let user_id = if is_reference { None } else { Some(user.id) };
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO interaction_rules (rule_type, source_group, target_group, impact_ratio, is_directional, description, is_reference, user_id, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now'))",
                params![
                    rule_type,
                    source_group,
                    target_group,
                    impact_ratio,
                    if is_directional { 1 } else { 0 },
                    attr_str(&attrs, "description"),
                    if is_reference { 1 } else { 0 },
                    user_id,
                    attr_str(&attrs, "region"),
                ],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, is_directional, description, region, is_reference, created_at, updated_at \
                 FROM interaction_rules WHERE id = ?1",
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
    ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets = Vec::new();
        let mut values: Vec<Value> = Vec::new();
        for key in [
            "rule_type",
            "source_group",
            "target_group",
            "description",
            "region",
        ] {
            if let Some(s) = attr_str(&attrs, key) {
                sets.push(format!("{key} = ?"));
                values.push(Value::Text(s));
            }
        }
        if let Some(v) = attr_f64(&attrs, "impact_ratio") {
            sets.push("impact_ratio = ?".into());
            values.push(Value::Real(v));
        }
        if let Some(b) = attr_bool(&attrs, "is_directional") {
            sets.push("is_directional = ?".into());
            values.push(Value::Integer(if b { 1 } else { 0 }));
        }
        if let Some(b) = attr_bool(&attrs, "is_reference") {
            sets.push("is_reference = ?".into());
            values.push(Value::Integer(if b { 1 } else { 0 }));
        }
        if sets.is_empty() {
            return self.find_by_id(id);
        }
        validate_region_attr(&attrs)?;
        sets.push("updated_at = datetime('now')".into());
        let sql = format!("UPDATE interaction_rules SET {} WHERE id = ?", sets.join(", "));
        values.push(Value::Integer(id));
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            conn.query_row(
                "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, is_directional, description, region, is_reference, created_at, updated_at \
                 FROM interaction_rules WHERE id = ?1",
                params![id],
                Self::row_to_entity,
            )
        })
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        rule_id: i64,
        auto_hide_after: i64,
        translator: &dyn TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        let rule = self.find_by_id(rule_id)?;
        let label = format!("{} {} {}", rule.rule_type, rule.source_group, rule.target_group);
        let toast = translator.t("interaction_rules.undo.toast", &TranslateOptions::default());
        match schedule_soft_delete_json(
            self.pool.clone(),
            "InteractionRule",
            rule_id,
            user.id,
            &toast,
            auto_hide_after,
            Some(&label),
        ) {
            SoftDeleteJsonOutcome::Success(undo) => Ok(SoftDeleteWithUndoOutcome::Success(
                SoftDeleteWithUndoSuccess { undo },
            )),
            SoftDeleteJsonOutcome::Failure(error) => Ok(SoftDeleteWithUndoOutcome::Failure(error)),
        }
    }
}
