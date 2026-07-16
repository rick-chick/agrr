//! Ruby: `CropActiveRecordGateway` — masters CRUD + index reads (P6).

use crate::deletion_undo::schedule_destroy;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::ports::PrivatePlanCropListGateway;
use agrr_domain::crop::dtos::{
    CropDeleteUsage, CropShowDetail, CropStageCreateInput, CropStageUpdateInput,
    NutrientRequirementUpdateInput,
    SunshineRequirementUpdateInput, TemperatureRequirementUpdateInput,
    ThermalRequirementUpdateInput,
};
use agrr_domain::crop::entities::{
    CropEntity, CropStageEntity, NutrientRequirementEntity, SunshineRequirementEntity,
    TemperatureRequirementEntity, ThermalRequirementEntity,
};
use agrr_domain::crop::gateways::{CropGateway, SoftDeleteWithUndoOutcome};
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use agrr_domain::shared::user::User;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};
use rusqlite::params;
use rust_decimal::Decimal;
use serde_json::{Map, Value};

pub struct CropSqliteGateway {
    pool: SqlitePool,
}

impl CropSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn map_crop_stage_sqlite_boxed_err(
    err: Box<dyn std::error::Error + Send + Sync>,
) -> Box<dyn std::error::Error + Send + Sync> {
    if let Some(sqlite_err) = err.downcast_ref::<rusqlite::Error>() {
        if let rusqlite::Error::SqliteFailure(code, msg) = sqlite_err {
            if code.code == rusqlite::ErrorCode::ConstraintViolation {
                let message = msg
                    .as_deref()
                    .unwrap_or("order has already been taken")
                    .to_string();
                return Box::new(RecordInvalidError::new(Some(message), None));
            }
        }
    }
    err
}

fn map_crop_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CropEntity> {
    let is_reference: i64 = row.get(4)?;
    let groups_text: Option<String> = row.get(8)?;
    Ok(CropEntity {
        id: row.get(0)?,
        user_id: row.get(1)?,
        name: row.get(2)?,
        variety: row.get(3)?,
        is_reference: is_reference != 0,
        area_per_unit: row.get(5)?,
        revenue_per_area: row.get(6)?,
        region: row.get(7)?,
        groups: parse_groups(groups_text),
        created_at: row.get(9)?,
        updated_at: row.get(10)?,
    })
}

fn parse_groups(raw: Option<String>) -> Vec<String> {
    raw.and_then(|s| serde_json::from_str::<Vec<String>>(&s).ok())
        .unwrap_or_default()
}

impl CropGateway for CropSqliteGateway {
    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let (sql, user_id) = match filter.mode {
            ReferenceIndexListMode::ReferenceOrOwned => (
                "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
                 FROM crops WHERE is_reference = 1 OR user_id = ?1 ORDER BY name",
                filter.user_id,
            ),
            ReferenceIndexListMode::OwnedNonReference => (
                "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
                 FROM crops WHERE user_id = ?1 AND is_reference = 0 ORDER BY name",
                filter.user_id,
            ),
        };
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(sql)?;
            let rows = stmt.query_map(params![user_id], map_crop_row)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn find_by_id(&self, crop_id: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
                 FROM crops WHERE id = ?1 LIMIT 1",
            )?;
            stmt.query_row(params![crop_id], map_crop_row)
        })
    }

    fn find_crop_show_detail(
        &self,
        crop_id: i64,
    ) -> Result<CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        let crop = self.find_by_id(crop_id)?;
        Ok(CropShowDetail { crop })
    }

    fn find_crop_record_with_stages(
        &self,
        crop_id: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.find_by_id(crop_id)
    }

    fn count_user_owned_non_reference_crops(
        &self,
        user_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM crops WHERE user_id = ?1 AND is_reference = 0",
                params![user_id],
                |row| row.get(0),
            )?;
            Ok(count as i32)
        })
    }

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = attrs
            .get("name")
            .and_then(|v| match v {
                AttrValue::Str(s) => Some(s.clone()),
                _ => None,
            })
            .ok_or_else(|| {
                Box::new(RecordInvalidError::new(Some("name is required".into()), None))
            })?;
        let variety = attrs.get("variety").and_then(|v| match v {
            AttrValue::Str(s) => Some(s.clone()),
            AttrValue::Null => None,
            _ => None,
        });
        let area_per_unit = attrs.get("area_per_unit").and_then(attr_as_f64);
        let revenue_per_area = attrs.get("revenue_per_area").and_then(attr_as_f64);
        let region = attrs.get("region").and_then(|v| match v {
            AttrValue::Str(s) => Some(s.clone()),
            _ => None,
        });
        let groups = attrs
            .get("groups")
            .and_then(|v| match v {
                AttrValue::Str(s) => Some(s.clone()),
                _ => None,
            })
            .unwrap_or_else(|| "[]".to_string());
        let is_reference = attrs
            .get("is_reference")
            .and_then(|v| match v {
                AttrValue::Bool(b) => Some(*b),
                _ => None,
            })
            .unwrap_or(false);

        let new_id = self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO crops (user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, datetime('now'), datetime('now'))",
                params![
                    user.id,
                    name,
                    variety,
                    if is_reference { 1 } else { 0 },
                    area_per_unit,
                    revenue_per_area,
                    region,
                    groups,
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })?;
        self.find_by_id(new_id)
    }

    fn update_for_user(
        &self,
        _user: &User,
        crop_id: i64,
        attrs: AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        if !attrs.is_empty() {
            self.pool.with_write_box(|conn| {
                if let Some(name) = attrs.get("name").and_then(|v| match v {
                    AttrValue::Str(s) => Some(s.as_str()),
                    _ => None,
                }) {
                    conn.execute(
                        "UPDATE crops SET name = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![name, crop_id],
                    )?;
                }
                if let Some(variety) = attrs.get("variety") {
                    let v = match variety {
                        AttrValue::Str(s) => Some(s.as_str()),
                        AttrValue::Null => None,
                        _ => None,
                    };
                    conn.execute(
                        "UPDATE crops SET variety = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, crop_id],
                    )?;
                }
                if let Some(v) = attrs.get("area_per_unit").and_then(attr_as_f64) {
                    conn.execute(
                        "UPDATE crops SET area_per_unit = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, crop_id],
                    )?;
                }
                if let Some(v) = attrs.get("revenue_per_area").and_then(attr_as_f64) {
                    conn.execute(
                        "UPDATE crops SET revenue_per_area = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, crop_id],
                    )?;
                }
                if let Some(region) = attrs.get("region").and_then(|v| match v {
                    AttrValue::Str(s) => Some(s.as_str()),
                    _ => None,
                }) {
                    conn.execute(
                        "UPDATE crops SET region = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![region, crop_id],
                    )?;
                }
                if let Some(groups) = attrs.get("groups").and_then(|v| match v {
                    AttrValue::Str(s) => Some(s.as_str()),
                    _ => None,
                }) {
                    conn.execute(
                        "UPDATE crops SET groups = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![groups, crop_id],
                    )?;
                }
                Ok(())
            })?;
        }
        self.find_by_id(crop_id)
    }

    fn find_delete_usage(
        &self,
        crop_id: i64,
    ) -> Result<CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let plan_crops: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_crops WHERE crop_id = ?1",
                params![crop_id],
                |row| row.get(0),
            )?;
            let free_plans: i64 = conn.query_row(
                "SELECT COUNT(*) FROM free_crop_plans WHERE crop_id = ?1",
                params![crop_id],
                |row| row.get(0),
            )?;
            let pesticides: i64 = conn.query_row(
                "SELECT COUNT(*) FROM pesticides WHERE crop_id = ?1",
                params![crop_id],
                |row| row.get(0),
            )?;
            Ok(CropDeleteUsage::new(
                plan_crops as i32,
                free_plans as i32,
                pesticides as i32,
            ))
        })
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        crop_id: i64,
        auto_hide_after: i64,
        toast_message: &str,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        match schedule_destroy(
            &self.pool,
            "Crop",
            crop_id,
            user.id,
            toast_message,
            auto_hide_after,
            Default::default(),
        ) {
            Ok(scheduled) => Ok(SoftDeleteWithUndoOutcome::Success {
                undo: serde_json::json!({
                    "undo_token": scheduled.undo_token,
                    "expires_at": scheduled.expires_at,
                }),
            }),
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                Ok(SoftDeleteWithUndoOutcome::Failure(Error::new(err.to_string())))
            }
            Err(err) => Err(err),
        }
    }

    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let ref_flag = if is_reference { 1 } else { 0 };
            let sql_with_region = "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
                     FROM crops WHERE is_reference = ?1 AND region = ?2 ORDER BY name";
            let sql_all = "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
                     FROM crops WHERE is_reference = ?1 ORDER BY name";
            let mut out = Vec::new();
            if let Some(region) = region.filter(|r| !r.is_empty()) {
                let mut stmt = conn.prepare(sql_with_region)?;
                let rows = stmt.query_map(params![ref_flag, region], map_crop_row)?;
                for row in rows {
                    out.push(row?);
                }
            } else {
                let mut stmt = conn.prepare(sql_all)?;
                let rows = stmt.query_map(params![ref_flag], map_crop_row)?;
                for row in rows {
                    out.push(row?);
                }
            }
            Ok(out)
        })
    }

    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| load_crop_stages(conn, crop_id))
    }

    fn create_crop_stage(
        &self,
        input: CropStageCreateInput,
    ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = input
            .payload
            .get("name")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .ok_or_else(|| RecordInvalidError::new(Some("name is required".into()), None))?;
        let order = input
            .payload
            .get("order")
            .and_then(|v| v.as_i64())
            .unwrap_or(0) as i32;
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at) VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
                params![input.crop_id, name, order],
            )?;
            let id = conn.last_insert_rowid();
            conn.query_row(
                "SELECT id, crop_id, name, \"order\", created_at, updated_at FROM crop_stages WHERE id = ?1",
                params![id],
                |row| {
                    Ok(CropStageEntity {
                        id: row.get(0)?,
                        crop_id: row.get(1)?,
                        name: row.get(2)?,
                        order: row.get(3)?,
                        temperature_requirement: None,
                        thermal_requirement: None,
                        sunshine_requirement: None,
                        nutrient_requirement: None,
                        created_at: row.get(4)?,
                        updated_at: row.get(5)?,
                    })
                },
            )
        })
    }

    fn update_crop_stage(
        &self,
        crop_stage_id: i64,
        input: CropStageUpdateInput,
    ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets: Vec<String> = Vec::new();
        let mut values: Vec<rusqlite::types::Value> = Vec::new();
        if let Some(name) = input.payload.get("name").and_then(|v| v.as_str()) {
            if name.is_empty() {
                return Err(Box::new(RecordInvalidError::new(
                    Some("name cannot be blank".into()),
                    None,
                )));
            }
            sets.push("name = ?".into());
            values.push(rusqlite::types::Value::Text(name.to_string()));
        }
        if let Some(order) = input.payload.get("order").and_then(|v| v.as_i64()) {
            sets.push("\"order\" = ?".into());
            values.push(rusqlite::types::Value::Integer(order));
        }
        if sets.is_empty() {
            return self.pool.with_read_box(|conn| load_crop_stage_by_id(conn, crop_stage_id).map_err(Into::into));
        }
        sets.push("updated_at = datetime('now')".into());
        let sql = format!("UPDATE crop_stages SET {} WHERE id = ?", sets.join(", "));
        values.push(rusqlite::types::Value::Integer(crop_stage_id));
        self.pool
            .with_write_box(|conn| {
                conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
                load_crop_stage_by_id(conn, crop_stage_id)
            })
            .map_err(map_crop_stage_sqlite_boxed_err)
    }

    fn reorder_crop_stages(
        &self,
        crop_id: i64,
        stage_orders: Vec<(i64, i64)>,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_transaction_box(|conn| {
            let mut old_orders = std::collections::HashMap::new();
            for (stage_id, _) in &stage_orders {
                let order = load_crop_stage_order(conn, crop_id, *stage_id)?;
                old_orders.insert(*stage_id, order);
            }

            for (stage_id, _) in &stage_orders {
                let updated = conn.execute(
                    "UPDATE crop_stages SET \"order\" = ?1, updated_at = datetime('now') \
                     WHERE id = ?2 AND crop_id = ?3",
                    params![-stage_id, stage_id, crop_id],
                )?;
                if updated == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }

            for (stage_id, order) in &stage_orders {
                let updated = conn.execute(
                    "UPDATE crop_stages SET \"order\" = ?1, updated_at = datetime('now') \
                     WHERE id = ?2 AND crop_id = ?3",
                    params![order, stage_id, crop_id],
                )?;
                if updated == 0 {
                    return Err(rusqlite::Error::QueryReturnedNoRows);
                }
            }

            remap_blueprint_stage_orders_after_reorder(conn, crop_id, &stage_orders, &old_orders)?;

            load_crop_stages(conn, crop_id)
        })
    }

    fn delete_crop_stage(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.pool.with_write_transaction_box(|conn| {
            let (crop_id, stage_order): (i64, i64) = conn
                .query_row(
                    "SELECT crop_id, \"order\" FROM crop_stages WHERE id = ?1",
                    params![crop_stage_id],
                    |row| Ok((row.get(0)?, row.get(1)?)),
                )
                .map_err(|_| rusqlite::Error::QueryReturnedNoRows)?;

            unassign_blueprints_for_stage_order(conn, crop_id, stage_order)?;
            delete_crop_stage_requirements(conn, crop_stage_id)?;
            let deleted = conn.execute(
                "DELETE FROM crop_stages WHERE id = ?1",
                params![crop_stage_id],
            )?;
            if deleted == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(())
        }) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<rusqlite::Error>().is_some_and(|e| {
                matches!(e, rusqlite::Error::QueryReturnedNoRows)
            }) =>
            {
                Err(Box::new(RecordNotFoundError) as Box<dyn std::error::Error + Send + Sync>)
            }
            Err(err) => Err(err),
        }
    }

    fn create_thermal_requirement(
        &self,
        crop_stage_id: i64,
        input: ThermalRequirementUpdateInput,
    ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "thermal_requirement");
        let gdd = f64_field(m, "required_gdd").unwrap_or(0.0);
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at) VALUES (?1, ?2, datetime('now'), datetime('now'))",
                params![crop_stage_id, gdd],
            )?;
            load_thermal(conn, crop_stage_id)
        })
    }

    fn update_thermal_requirement(
        &self,
        crop_stage_id: i64,
        input: ThermalRequirementUpdateInput,
    ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "thermal_requirement");
        self.pool.with_write_box(|conn| {
            let mut sets = Vec::new();
            let mut values = Vec::new();
            push_f64_patch(
                &mut sets,
                &mut values,
                "required_gdd",
                patch_f64(m, "required_gdd"),
            );
            if sets.is_empty() {
                return load_thermal(conn, crop_stage_id).map_err(Into::into);
            }
            sets.push("updated_at = datetime('now')".into());
            let sql = format!(
                "UPDATE thermal_requirements SET {} WHERE crop_stage_id = ?",
                sets.join(", ")
            );
            values.push(rusqlite::types::Value::Integer(crop_stage_id));
            let updated = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            load_thermal(conn, crop_stage_id)
        })
    }

    fn delete_thermal_requirement(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let n = conn.execute(
                "DELETE FROM thermal_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
            )?;
            if n == 0 {
                Err(rusqlite::Error::QueryReturnedNoRows)
            } else {
                Ok(())
            }
        })
    }

    fn create_temperature_requirement(
        &self,
        crop_stage_id: i64,
        input: TemperatureRequirementUpdateInput,
    ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "temperature_requirement");
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now'))",
                params![
                    crop_stage_id,
                    f64_field(m, "base_temperature"),
                    f64_field(m, "optimal_min"),
                    f64_field(m, "optimal_max"),
                    f64_field(m, "low_stress_threshold"),
                    f64_field(m, "high_stress_threshold"),
                    f64_field(m, "frost_threshold"),
                    f64_field(m, "sterility_risk_threshold"),
                    f64_field(m, "max_temperature"),
                ],
            )?;
            load_temperature(conn, crop_stage_id)
        })
    }

    fn update_temperature_requirement(
        &self,
        crop_stage_id: i64,
        input: TemperatureRequirementUpdateInput,
    ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "temperature_requirement");
        self.pool.with_write_box(|conn| {
            let mut sets = Vec::new();
            let mut values = Vec::new();
            push_f64_patch(
                &mut sets,
                &mut values,
                "base_temperature",
                patch_f64(m, "base_temperature"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "optimal_min",
                patch_f64(m, "optimal_min"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "optimal_max",
                patch_f64(m, "optimal_max"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "low_stress_threshold",
                patch_f64(m, "low_stress_threshold"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "high_stress_threshold",
                patch_f64(m, "high_stress_threshold"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "frost_threshold",
                patch_f64(m, "frost_threshold"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "sterility_risk_threshold",
                patch_f64(m, "sterility_risk_threshold"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "max_temperature",
                patch_f64(m, "max_temperature"),
            );
            if sets.is_empty() {
                return load_temperature(conn, crop_stage_id).map_err(Into::into);
            }
            sets.push("updated_at = datetime('now')".into());
            let sql = format!(
                "UPDATE temperature_requirements SET {} WHERE crop_stage_id = ?",
                sets.join(", ")
            );
            values.push(rusqlite::types::Value::Integer(crop_stage_id));
            let updated = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            load_temperature(conn, crop_stage_id)
        })
    }

    fn delete_temperature_requirement(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let n = conn.execute(
                "DELETE FROM temperature_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
            )?;
            if n == 0 {
                Err(rusqlite::Error::QueryReturnedNoRows)
            } else {
                Ok(())
            }
        })
    }

    fn create_sunshine_requirement(
        &self,
        crop_stage_id: i64,
        input: SunshineRequirementUpdateInput,
    ) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "sunshine_requirement");
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO sunshine_requirements (crop_stage_id, minimum_sunshine_hours, target_sunshine_hours, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, datetime('now'), datetime('now'))",
                params![
                    crop_stage_id,
                    f64_field(m, "minimum_sunshine_hours"),
                    f64_field(m, "target_sunshine_hours"),
                ],
            )?;
            load_sunshine(conn, crop_stage_id)
        })
    }

    fn update_sunshine_requirement(
        &self,
        crop_stage_id: i64,
        input: SunshineRequirementUpdateInput,
    ) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "sunshine_requirement");
        self.pool.with_write_box(|conn| {
            let mut sets = Vec::new();
            let mut values = Vec::new();
            push_f64_patch(
                &mut sets,
                &mut values,
                "minimum_sunshine_hours",
                patch_f64(m, "minimum_sunshine_hours"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "target_sunshine_hours",
                patch_f64(m, "target_sunshine_hours"),
            );
            if sets.is_empty() {
                return load_sunshine(conn, crop_stage_id).map_err(Into::into);
            }
            sets.push("updated_at = datetime('now')".into());
            let sql = format!(
                "UPDATE sunshine_requirements SET {} WHERE crop_stage_id = ?",
                sets.join(", ")
            );
            values.push(rusqlite::types::Value::Integer(crop_stage_id));
            let updated = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            load_sunshine(conn, crop_stage_id)
        })
    }

    fn delete_sunshine_requirement(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let n = conn.execute(
                "DELETE FROM sunshine_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
            )?;
            if n == 0 {
                Err(rusqlite::Error::QueryReturnedNoRows)
            } else {
                Ok(())
            }
        })
    }

    fn create_nutrient_requirement(
        &self,
        crop_stage_id: i64,
        input: NutrientRequirementUpdateInput,
    ) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "nutrient_requirement");
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO nutrient_requirements (crop_stage_id, daily_uptake_n, daily_uptake_p, daily_uptake_k, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'), datetime('now'))",
                params![
                    crop_stage_id,
                    f64_field(m, "daily_uptake_n"),
                    f64_field(m, "daily_uptake_p"),
                    f64_field(m, "daily_uptake_k"),
                    str_field(m, "region"),
                ],
            )?;
            load_nutrient(conn, crop_stage_id)
        })
    }

    fn update_nutrient_requirement(
        &self,
        crop_stage_id: i64,
        input: NutrientRequirementUpdateInput,
    ) -> Result<NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        let m = nested_req_map(&input.payload, "nutrient_requirement");
        self.pool.with_write_box(|conn| {
            let mut sets = Vec::new();
            let mut values = Vec::new();
            push_f64_patch(
                &mut sets,
                &mut values,
                "daily_uptake_n",
                patch_f64(m, "daily_uptake_n"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "daily_uptake_p",
                patch_f64(m, "daily_uptake_p"),
            );
            push_f64_patch(
                &mut sets,
                &mut values,
                "daily_uptake_k",
                patch_f64(m, "daily_uptake_k"),
            );
            push_str_patch(&mut sets, &mut values, "region", patch_str(m, "region"));
            if sets.is_empty() {
                return load_nutrient(conn, crop_stage_id).map_err(Into::into);
            }
            sets.push("updated_at = datetime('now')".into());
            let sql = format!(
                "UPDATE nutrient_requirements SET {} WHERE crop_stage_id = ?",
                sets.join(", ")
            );
            values.push(rusqlite::types::Value::Integer(crop_stage_id));
            let updated = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            if updated == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            load_nutrient(conn, crop_stage_id)
        })
    }

    fn delete_nutrient_requirement(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let n = conn.execute(
                "DELETE FROM nutrient_requirements WHERE crop_stage_id = ?1",
                params![crop_stage_id],
            )?;
            if n == 0 {
                Err(rusqlite::Error::QueryReturnedNoRows)
            } else {
                Ok(())
            }
        })
    }
}

fn attr_as_f64(v: &AttrValue) -> Option<f64> {
    match v {
        AttrValue::Str(s) => s.parse().ok(),
        AttrValue::Int(i) => Some(*i as f64),
        _ => None,
    }
}

impl PrivatePlanCropListGateway for CropSqliteGateway {
    fn list_by_ids(
        &self,
        crop_ids: &[i64],
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if crop_ids.is_empty() {
            return Ok(Vec::new());
        }
        let placeholders = crop_ids
            .iter()
            .enumerate()
            .map(|(i, _)| format!("?{}", i + 1))
            .collect::<Vec<_>>()
            .join(", ");
        let sql = format!(
            "SELECT id, user_id, name, variety, is_reference, area_per_unit, revenue_per_area, region, groups, created_at, updated_at \
             FROM crops WHERE id IN ({placeholders})"
        );
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let params: Vec<i64> = crop_ids.to_vec();
            let rows = stmt.query_map(rusqlite::params_from_iter(params.iter()), map_crop_row)?;
            let mut by_id = std::collections::HashMap::new();
            for row in rows {
                let entity = row?;
                by_id.insert(entity.id, entity);
            }
            Ok(crop_ids
                .iter()
                .filter_map(|id| by_id.get(id).cloned())
                .collect())
        })
    }
}

fn load_crop_stage_order(
    conn: &rusqlite::Connection,
    crop_id: i64,
    stage_id: i64,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT \"order\" FROM crop_stages WHERE id = ?1 AND crop_id = ?2",
        params![stage_id, crop_id],
        |row| row.get(0),
    )
}

fn remap_blueprint_stage_orders_after_reorder(
    conn: &rusqlite::Connection,
    crop_id: i64,
    stage_orders: &[(i64, i64)],
    old_orders: &std::collections::HashMap<i64, i64>,
) -> rusqlite::Result<()> {
    for (stage_id, new_order) in stage_orders {
        let old_order = old_orders[stage_id];
        if old_order == *new_order {
            continue;
        }
        conn.execute(
            "UPDATE crop_task_schedule_blueprints SET stage_order = ?1, updated_at = datetime('now') \
             WHERE crop_id = ?2 AND stage_order = ?3",
            params![-stage_id, crop_id, old_order],
        )?;
    }

    for (stage_id, new_order) in stage_orders {
        let old_order = old_orders[stage_id];
        if old_order == *new_order {
            continue;
        }
        conn.execute(
            "UPDATE crop_task_schedule_blueprints SET stage_order = ?1, updated_at = datetime('now') \
             WHERE crop_id = ?2 AND stage_order = ?3",
            params![new_order, crop_id, -stage_id],
        )?;
    }

    Ok(())
}

fn unassign_blueprints_for_stage_order(
    conn: &rusqlite::Connection,
    crop_id: i64,
    stage_order: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "UPDATE crop_task_schedule_blueprints SET stage_order = NULL, stage_name = NULL, updated_at = datetime('now') \
         WHERE crop_id = ?1 AND stage_order = ?2",
        params![crop_id, stage_order],
    )?;
    Ok(())
}

/// Rails `CropStage` `dependent: :destroy` on requirement associations.
fn delete_crop_stage_requirements(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM temperature_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
    )?;
    conn.execute(
        "DELETE FROM thermal_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
    )?;
    conn.execute(
        "DELETE FROM sunshine_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
    )?;
    conn.execute(
        "DELETE FROM nutrient_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
    )?;
    Ok(())
}

fn load_crop_stage_by_id(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<CropStageEntity> {
    let stage = conn.query_row(
        "SELECT id, crop_id, name, \"order\", created_at, updated_at FROM crop_stages WHERE id = ?1",
        params![crop_stage_id],
        |row| {
            Ok(CropStageEntity {
                id: row.get(0)?,
                crop_id: row.get(1)?,
                name: row.get(2)?,
                order: row.get(3)?,
                temperature_requirement: None,
                thermal_requirement: None,
                sunshine_requirement: None,
                nutrient_requirement: None,
                created_at: row.get(4)?,
                updated_at: row.get(5)?,
            })
        },
    )?;
    hydrate_crop_stage_requirements(conn, stage)
}

/// Ruby `CropStageRequirementEntitySupport#crop_stage_entity_from_record` parity.
fn hydrate_crop_stage_requirements(
    conn: &rusqlite::Connection,
    mut stage: CropStageEntity,
) -> rusqlite::Result<CropStageEntity> {
    stage.temperature_requirement = load_temperature(conn, stage.id).ok();
    stage.thermal_requirement = load_thermal(conn, stage.id).ok();
    stage.sunshine_requirement = load_sunshine(conn, stage.id).ok();
    stage.nutrient_requirement = load_nutrient(conn, stage.id).ok();
    Ok(stage)
}

fn nested_req_map<'a>(payload: &'a Value, key: &str) -> &'a Map<String, Value> {
    payload
        .get(key)
        .and_then(|v| v.as_object())
        .or_else(|| payload.as_object())
        .expect("requirement payload object")
}

/// Domain DTOs often encode decimals as JSON strings (`decimal_json` in stage copy).
fn f64_field(m: &Map<String, Value>, key: &str) -> Option<f64> {
    match m.get(key)? {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

enum PatchField<T> {
    Absent,
    Set(Option<T>),
}

fn patch_f64(m: &Map<String, Value>, key: &str) -> PatchField<f64> {
    match m.get(key) {
        None => PatchField::Absent,
        Some(Value::Null) => PatchField::Set(None),
        Some(value) => f64_field_from_value(value)
            .map(|n| PatchField::Set(Some(n)))
            .unwrap_or(PatchField::Absent),
    }
}

fn patch_str(m: &Map<String, Value>, key: &str) -> PatchField<String> {
    match m.get(key) {
        None => PatchField::Absent,
        Some(Value::Null) => PatchField::Set(None),
        Some(Value::String(s)) => PatchField::Set(Some(s.clone())),
        _ => PatchField::Absent,
    }
}

fn f64_field_from_value(value: &Value) -> Option<f64> {
    match value {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn push_f64_patch(
    sets: &mut Vec<String>,
    values: &mut Vec<rusqlite::types::Value>,
    column: &str,
    patch: PatchField<f64>,
) {
    if let PatchField::Set(value) = patch {
        sets.push(format!("{column} = ?"));
        values.push(match value {
            Some(n) => rusqlite::types::Value::Real(n),
            None => rusqlite::types::Value::Null,
        });
    }
}

fn push_str_patch(
    sets: &mut Vec<String>,
    values: &mut Vec<rusqlite::types::Value>,
    column: &str,
    patch: PatchField<String>,
) {
    if let PatchField::Set(value) = patch {
        sets.push(format!("{column} = ?"));
        values.push(match value {
            Some(s) => rusqlite::types::Value::Text(s),
            None => rusqlite::types::Value::Null,
        });
    }
}

fn str_field(m: &Map<String, Value>, key: &str) -> Option<String> {
    m.get(key).and_then(|v| v.as_str()).map(str::to_string)
}

fn dec_opt(v: Option<f64>) -> Option<Decimal> {
    v.and_then(Decimal::from_f64_retain)
}

fn load_temperature(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<TemperatureRequirementEntity> {
    conn.query_row(
        "SELECT id, crop_stage_id, base_temperature, optimal_min, optimal_max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature FROM temperature_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
        |row| {
            Ok(TemperatureRequirementEntity {
                id: row.get(0)?,
                crop_stage_id: row.get(1)?,
                base_temperature: dec_opt(row.get(2)?),
                optimal_min: dec_opt(row.get(3)?),
                optimal_max: dec_opt(row.get(4)?),
                low_stress_threshold: dec_opt(row.get(5)?),
                high_stress_threshold: dec_opt(row.get(6)?),
                frost_threshold: dec_opt(row.get(7)?),
                sterility_risk_threshold: dec_opt(row.get(8)?),
                max_temperature: dec_opt(row.get(9)?),
            })
        },
    )
}

fn load_thermal(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<ThermalRequirementEntity> {
    conn.query_row(
        "SELECT id, crop_stage_id, required_gdd FROM thermal_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
        |row| {
            ThermalRequirementEntity::new(
                row.get(0)?,
                row.get(1)?,
                dec_opt(row.get(2)?),
            )
            .map_err(|e| {
                rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    e,
                )))
            })
        },
    )
}

fn load_sunshine(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<SunshineRequirementEntity> {
    conn.query_row(
        "SELECT id, crop_stage_id, minimum_sunshine_hours, target_sunshine_hours FROM sunshine_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
        |row| {
            Ok(SunshineRequirementEntity {
                id: row.get(0)?,
                crop_stage_id: row.get(1)?,
                minimum_sunshine_hours: dec_opt(row.get(2)?),
                target_sunshine_hours: dec_opt(row.get(3)?),
            })
        },
    )
}

fn load_nutrient(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<NutrientRequirementEntity> {
    conn.query_row(
        "SELECT id, crop_stage_id, daily_uptake_n, daily_uptake_p, daily_uptake_k, region FROM nutrient_requirements WHERE crop_stage_id = ?1",
        params![crop_stage_id],
        |row| {
            Ok(NutrientRequirementEntity {
                id: row.get(0)?,
                crop_stage_id: row.get(1)?,
                daily_uptake_n: dec_opt(row.get(2)?),
                daily_uptake_p: dec_opt(row.get(3)?),
                daily_uptake_k: dec_opt(row.get(4)?),
                region: row.get(5)?,
            })
        },
    )
}

pub(crate) fn load_crop_stages(
    conn: &rusqlite::Connection,
    crop_id: i64,
) -> rusqlite::Result<Vec<CropStageEntity>> {
    let mut stmt = conn.prepare(
        "SELECT id, crop_id, name, \"order\", created_at, updated_at FROM crop_stages WHERE crop_id = ?1 ORDER BY \"order\"",
    )?;
    let rows = stmt.query_map(params![crop_id], |row| {
        Ok(CropStageEntity {
            id: row.get(0)?,
            crop_id: row.get(1)?,
            name: row.get(2)?,
            order: row.get(3)?,
            temperature_requirement: None,
            thermal_requirement: None,
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: row.get(4)?,
            updated_at: row.get(5)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(hydrate_crop_stage_requirements(conn, row?)?);
    }
    Ok(out)
}
