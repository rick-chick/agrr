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
use agrr_domain::crop::gateways::{
    CropGateway, SoftDeleteWithUndoOutcome, UpdateMastersCropTaskTemplateOutcome,
};
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

fn unsupported(method: &str) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        format!("{method} not supported in P6 crop read slice"),
    ))
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
        self.pool.with_write_box(|conn| {
            conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            load_crop_stage_by_id(conn, crop_stage_id)
        })
    }

    fn delete_crop_stage(
        &self,
        crop_stage_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.pool.with_write_box(|conn| {
            conn.execute("DELETE FROM crop_stages WHERE id = ?1", params![crop_stage_id])
        }) {
            Ok(0) => Err(Box::new(RecordNotFoundError) as Box<dyn std::error::Error + Send + Sync>),
            Ok(_) => Ok(()),
            Err(e) => Err(e),
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
            let updated = conn.execute(
                "UPDATE thermal_requirements SET required_gdd = COALESCE(?2, required_gdd), updated_at = datetime('now') WHERE crop_stage_id = ?1",
                params![crop_stage_id, f64_field(m, "required_gdd")],
            )?;
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
            let updated = conn.execute(
                "UPDATE temperature_requirements SET base_temperature = COALESCE(?2, base_temperature), optimal_min = COALESCE(?3, optimal_min), optimal_max = COALESCE(?4, optimal_max), \
                 low_stress_threshold = COALESCE(?5, low_stress_threshold), high_stress_threshold = COALESCE(?6, high_stress_threshold), frost_threshold = COALESCE(?7, frost_threshold), \
                 sterility_risk_threshold = COALESCE(?8, sterility_risk_threshold), max_temperature = COALESCE(?9, max_temperature), updated_at = datetime('now') WHERE crop_stage_id = ?1",
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
            let updated = conn.execute(
                "UPDATE sunshine_requirements SET minimum_sunshine_hours = COALESCE(?2, minimum_sunshine_hours), target_sunshine_hours = COALESCE(?3, target_sunshine_hours), updated_at = datetime('now') WHERE crop_stage_id = ?1",
                params![
                    crop_stage_id,
                    f64_field(m, "minimum_sunshine_hours"),
                    f64_field(m, "target_sunshine_hours"),
                ],
            )?;
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
            let updated = conn.execute(
                "UPDATE nutrient_requirements SET daily_uptake_n = COALESCE(?2, daily_uptake_n), daily_uptake_p = COALESCE(?3, daily_uptake_p), daily_uptake_k = COALESCE(?4, daily_uptake_k), region = COALESCE(?5, region), updated_at = datetime('now') WHERE crop_stage_id = ?1",
                params![
                    crop_stage_id,
                    f64_field(m, "daily_uptake_n"),
                    f64_field(m, "daily_uptake_p"),
                    f64_field(m, "daily_uptake_k"),
                    str_field(m, "region"),
                ],
            )?;
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

    fn masters_crop_agricultural_task_templates_index_rows(
        &self,
        _crop_id: i64,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>> {
        Err(unsupported("masters_crop_agricultural_task_templates_index_rows"))
    }

    fn update_masters_crop_task_template_for_api(
        &self,
        _crop_id: i64,
        _template_id: i64,
        _attributes: Value,
    ) -> Result<UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>>
    {
        Err(unsupported("update_masters_crop_task_template_for_api"))
    }

    fn delete_masters_crop_task_template(
        &self,
        _crop_id: i64,
        _template_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err(unsupported("delete_masters_crop_task_template"))
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
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }
}

fn load_crop_stage_by_id(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<CropStageEntity> {
    conn.query_row(
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
    )
}

fn nested_req_map<'a>(payload: &'a Value, key: &str) -> &'a Map<String, Value> {
    payload
        .get(key)
        .and_then(|v| v.as_object())
        .or_else(|| payload.as_object())
        .expect("requirement payload object")
}

fn f64_field(m: &Map<String, Value>, key: &str) -> Option<f64> {
    m.get(key).and_then(|v| v.as_f64())
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
            let gdd: f64 = row.get(2)?;
            ThermalRequirementEntity::new(
                row.get(0)?,
                row.get(1)?,
                Decimal::from_f64_retain(gdd).unwrap_or_default(),
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
        out.push(row?);
    }
    Ok(out)
}
