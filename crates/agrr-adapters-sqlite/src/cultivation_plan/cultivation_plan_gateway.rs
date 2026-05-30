//! Ruby: `CultivationPlanActiveRecordGateway` — P6 read slice (`find_by_id` only).

use crate::deletion_undo::schedule_destroy;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use agrr_domain::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::ports::PrivatePlanExistingPlanGateway;
use agrr_domain::shared::user::User;
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::collections::HashMap;

pub struct CultivationPlanSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CultivationPlanGateway for CultivationPlanSqliteGateway {
    fn find_by_id(
        &self,
        plan_id: i64,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read_box(|conn| load_plan_entity(conn, plan_id))
    }

    fn create(
        &self,
        attrs: &CultivationPlanCreateAttrs,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let planning_start = attrs
                .planning_start_date
                .map(|d| d.to_string())
                .unwrap_or_default();
            let planning_end = attrs
                .planning_end_date
                .map(|d| d.to_string())
                .unwrap_or_default();
            let status = attrs.status.as_deref().unwrap_or("pending");
            conn.execute(
                "INSERT INTO cultivation_plans \
                 (farm_id, user_id, session_id, total_area, status, plan_type, plan_year, plan_name, \
                  planning_start_date, planning_end_date, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, datetime('now'), datetime('now'))",
                params![
                    attrs.farm_id,
                    attrs.user_id,
                    attrs.session_id,
                    attrs.total_area,
                    status,
                    attrs.plan_type,
                    attrs.plan_year,
                    attrs.plan_name,
                    planning_start,
                    planning_end,
                ],
            )?;
            let id = conn.last_insert_rowid();
            load_plan_entity(conn, id)
        })
    }

    fn update(
        &self,
        plan_id: i64,
        attrs: HashMap<String, String>,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        if attrs.is_empty() {
            return self.find_by_id(plan_id);
        }
        self.pool.with_write_box(|conn| {
            let mut sets = Vec::new();
            let mut values: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();
            for (key, value) in &attrs {
                match key.as_str() {
                    "status" | "optimization_phase" | "optimization_phase_message" | "plan_name" => {
                        sets.push(format!("{key} = ?"));
                        values.push(Box::new(value.clone()));
                    }
                    _ => {}
                }
            }
            if sets.is_empty() {
                return load_plan_entity(conn, plan_id);
            }
            sets.push("updated_at = datetime('now')".into());
            let sql = format!(
                "UPDATE cultivation_plans SET {} WHERE id = ?",
                sets.join(", ")
            );
            values.push(Box::new(plan_id));
            let params: Vec<&dyn rusqlite::types::ToSql> =
                values.iter().map(|v| v.as_ref()).collect();
            conn.execute(&sql, params.as_slice())?;
            load_plan_entity(conn, plan_id)
        })
    }

    fn list_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, \
                 area, status \
                 FROM field_cultivations WHERE cultivation_plan_id = ?1",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                Ok(FieldCultivationEntity {
                    id: row.get(0)?,
                    cultivation_plan_id: row.get(1)?,
                    cultivation_plan_field_id: row.get(2)?,
                    cultivation_plan_crop_id: row.get(3)?,
                    area: row.get(4)?,
                    status: row.get(5)?,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn within_transaction<F, T>(
        &self,
        block: F,
    ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
    {
        // P6: nested `with_write` from gateway methods would deadlock on the pool mutex;
        // run the block without an explicit SQL transaction until a connection-scoped API exists.
        block()
    }

    fn private_owned_plan_display_name(
        &self,
        _user: &User,
        plan_id: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT COALESCE(NULLIF(TRIM(cp.plan_name), ''), f.name) \
                 FROM cultivation_plans cp INNER JOIN farms f ON f.id = cp.farm_id \
                 WHERE cp.id = ?1",
                params![plan_id],
                |row| row.get(0),
            )
        })
    }

    fn delete(
        &self,
        plan_id: i64,
        user: &User,
        toast_message: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let scheduled = schedule_destroy(
            &self.pool,
            "CultivationPlan",
            plan_id,
            user.id,
            toast_message,
            5,
            BTreeMap::new(),
        )?;
        Ok(json!({
            "undo_token": scheduled.undo_token,
            "undo_deadline": scheduled.metadata.get("undo_deadline"),
            "toast_message": scheduled.metadata.get("toast_message"),
            "auto_hide_after": scheduled.metadata.get("auto_hide_after"),
            "resource": scheduled.metadata.get("resource_label"),
            "resource_dom_id": scheduled.metadata.get("resource_dom_id"),
        }))
    }
}

impl PrivatePlanExistingPlanGateway for CultivationPlanSqliteGateway {
    fn find_existing(
        &self,
        farm_id: i64,
        user_id: i64,
    ) -> Result<Option<CultivationPlanEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT cp.id, cp.farm_id, COALESCE(cp.user_id, 0), COALESCE(cp.total_area, 0), \
                 cp.plan_type, cp.plan_year, cp.plan_name, cp.planning_start_date, cp.planning_end_date, \
                 cp.status, cp.session_id, \
                 (SELECT COUNT(*) FROM cultivation_plan_crops cpc WHERE cpc.cultivation_plan_id = cp.id), \
                 (SELECT COUNT(*) FROM cultivation_plan_fields cpf WHERE cpf.cultivation_plan_id = cp.id), \
                 cp.created_at, cp.updated_at \
                 FROM cultivation_plans cp \
                 WHERE cp.farm_id = ?1 AND cp.user_id = ?2 AND cp.plan_type = 'private' LIMIT 1",
            )?;
            let row = stmt
                .query_row(params![farm_id, user_id], |row| {
                    Ok(CultivationPlanEntity {
                        id: row.get(0)?,
                        farm_id: row.get(1)?,
                        user_id: row.get(2)?,
                        total_area: row.get(3)?,
                        plan_type: row.get(4)?,
                        plan_year: row.get(5)?,
                        plan_name: row.get(6)?,
                        planning_start_date: row.get(7)?,
                        planning_end_date: row.get(8)?,
                        status: row.get(9)?,
                        session_id: row.get(10)?,
                        display_name: None,
                        optimization_phase: None,
                        optimization_phase_message: None,
                        cultivation_plan_crops_count: row.get(11)?,
                        cultivation_plan_fields_count: row.get(12)?,
                        created_at: row.get(13)?,
                        updated_at: row.get(14)?,
                    })
                })
                .optional()?;
            Ok(row)
        })
    }
}

fn load_plan_entity(conn: &rusqlite::Connection, plan_id: i64) -> rusqlite::Result<CultivationPlanEntity> {
    let mut stmt = conn.prepare(
        "SELECT cp.id, cp.farm_id, COALESCE(cp.user_id, 0), COALESCE(cp.total_area, 0), \
         cp.plan_type, cp.plan_year, cp.plan_name, cp.planning_start_date, cp.planning_end_date, \
         cp.status, cp.session_id, cp.optimization_phase, cp.optimization_phase_message, \
         (SELECT COUNT(*) FROM cultivation_plan_crops cpc WHERE cpc.cultivation_plan_id = cp.id), \
         (SELECT COUNT(*) FROM cultivation_plan_fields cpf WHERE cpf.cultivation_plan_id = cp.id), \
         cp.created_at, cp.updated_at \
         FROM cultivation_plans cp WHERE cp.id = ?1 LIMIT 1",
    )?;
    stmt.query_row(params![plan_id], |row| {
        Ok(CultivationPlanEntity {
            id: row.get(0)?,
            farm_id: row.get(1)?,
            user_id: row.get(2)?,
            total_area: row.get(3)?,
            plan_type: row.get(4)?,
            plan_year: row.get(5)?,
            plan_name: row.get(6)?,
            planning_start_date: row.get(7)?,
            planning_end_date: row.get(8)?,
            status: row.get(9)?,
            session_id: row.get(10)?,
            display_name: None,
            optimization_phase: row.get(11)?,
            optimization_phase_message: row.get(12)?,
            cultivation_plan_crops_count: row.get(13)?,
            cultivation_plan_fields_count: row.get(14)?,
            created_at: row.get(15)?,
            updated_at: row.get(16)?,
        })
    })
}
