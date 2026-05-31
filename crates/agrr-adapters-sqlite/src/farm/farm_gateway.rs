//! Ruby: `FarmActiveRecordGateway` — masters CRUD + reference reads (P6).

use crate::deletion_undo::schedule_destroy;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::ports::PrivatePlanFarmResolveGateway;
use agrr_domain::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
use agrr_domain::farm::entities::{FarmEntity, FieldEntity};
use agrr_domain::farm::gateways::{FarmGateway, SoftDeleteWithUndoOutcome};
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordInvalidError;
use agrr_domain::shared::user::User;
use rusqlite::params;
use serde_json::json;

pub struct FarmSqliteGateway {
    pool: SqlitePool,
}

impl FarmSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn map_farm_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FarmEntity> {
    let is_reference: i64 = row.get(6)?;
    Ok(FarmEntity {
        id: row.get(0)?,
        name: row.get(1)?,
        latitude: row.get(2)?,
        longitude: row.get(3)?,
        region: row.get(4)?,
        user_id: row.get(5)?,
        created_at: row.get(7)?,
        updated_at: row.get(8)?,
        is_reference: is_reference != 0,
        weather_data_status: row.get(9)?,
        weather_data_fetched_years: row.get(10)?,
        weather_data_total_years: row.get(11)?,
        weather_data_last_error: row.get(12)?,
        weather_location_id: row.get(13)?,
        last_broadcast_at: row.get(14)?,
    })
}

const FARM_SELECT: &str = "SELECT id, name, latitude, longitude, region, user_id, is_reference, created_at, updated_at, \
    weather_data_status, weather_data_fetched_years, weather_data_total_years, weather_data_last_error, \
    weather_location_id, last_broadcast_at FROM farms";

impl FarmGateway for FarmSqliteGateway {
    fn list_user_owned_farms(
        &self,
        user_id: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&format!(
                "{FARM_SELECT} WHERE user_id = ?1 AND is_reference = 0 ORDER BY name"
            ))?;
            let rows = stmt.query_map(params![user_id], map_farm_row)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn list_user_and_reference_farms(
        &self,
        user_id: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&format!(
                "{FARM_SELECT} WHERE is_reference = 1 OR user_id = ?1 ORDER BY name"
            ))?;
            let rows = stmt.query_map(params![user_id], map_farm_row)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn list_reference_farms(
        &self,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.list_reference_farms_for_region("")
    }

    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&format!("{FARM_SELECT} WHERE id = ?1 LIMIT 1"))?;
            let row = stmt.query_row(params![farm_id], map_farm_row)?;
            Ok(row)
        })
    }

    fn update_weather_progress(
        &self,
        farm_id: i64,
        attrs: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        if !attrs.is_empty() {
            self.pool.with_write_box(|conn| {
                if let Some(v) = attrs.get("weather_data_status").and_then(attr_as_str) {
                    conn.execute(
                        "UPDATE farms SET weather_data_status = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("weather_data_fetched_years").and_then(attr_as_i64) {
                    conn.execute(
                        "UPDATE farms SET weather_data_fetched_years = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("weather_data_total_years").and_then(attr_as_i64) {
                    conn.execute(
                        "UPDATE farms SET weather_data_total_years = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("weather_data_last_error") {
                    match v {
                        AttrValue::Null => {
                            conn.execute(
                                "UPDATE farms SET weather_data_last_error = NULL, updated_at = datetime('now') WHERE id = ?1",
                                params![farm_id],
                            )?;
                        }
                        AttrValue::Str(s) => {
                            conn.execute(
                                "UPDATE farms SET weather_data_last_error = ?1, updated_at = datetime('now') WHERE id = ?2",
                                params![s, farm_id],
                            )?;
                        }
                        _ => {}
                    }
                }
                if let Some(v) = attrs.get("weather_location_id") {
                    match v {
                        AttrValue::Null => {
                            conn.execute(
                                "UPDATE farms SET weather_location_id = NULL, updated_at = datetime('now') WHERE id = ?1",
                                params![farm_id],
                            )?;
                        }
                        AttrValue::Int(id) => {
                            conn.execute(
                                "UPDATE farms SET weather_location_id = ?1, updated_at = datetime('now') WHERE id = ?2",
                                params![id, farm_id],
                            )?;
                        }
                        _ => {}
                    }
                }
                if let Some(v) = attrs.get("last_broadcast_at").and_then(attr_as_i64) {
                    conn.execute(
                        "UPDATE farms SET last_broadcast_at = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v as f64, farm_id],
                    )?;
                }
                Ok(())
            })?;
        }
        FarmGateway::find_by_id(self, farm_id)
    }

    fn list_reference_farms_for_region(
        &self,
        region: &str,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let (sql, bind_region) = if region.is_empty() {
                (
                    format!("{FARM_SELECT} WHERE is_reference = 1 ORDER BY name"),
                    false,
                )
            } else {
                (
                    format!("{FARM_SELECT} WHERE is_reference = 1 AND region = ?1 ORDER BY name"),
                    true,
                )
            };
            let mut stmt = conn.prepare(&sql)?;
            let rows = if bind_region {
                stmt.query_map(params![region], map_farm_row)?
            } else {
                stmt.query_map([], map_farm_row)?
            };
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn count_user_owned_non_reference_farms(
        &self,
        user_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM farms WHERE user_id = ?1 AND is_reference = 0",
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
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        let name = required_str(&attrs, "name")?;
        let region = attrs.get("region").and_then(attr_as_str);
        let latitude = required_f64(&attrs, "latitude")?;
        let longitude = required_f64(&attrs, "longitude")?;
        let is_reference = attrs
            .get("is_reference")
            .and_then(|v| match v {
                AttrValue::Bool(b) => Some(*b),
                _ => None,
            })
            .unwrap_or(false);

        let new_id = self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO farms (user_id, name, latitude, longitude, region, is_reference, \
                 weather_data_status, weather_data_fetched_years, weather_data_total_years, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'pending', 0, 0, datetime('now'), datetime('now'))",
                params![
                    user.id,
                    name,
                    latitude,
                    longitude,
                    region,
                    if is_reference { 1 } else { 0 },
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })?;
        FarmGateway::find_by_id(self, new_id)
    }

    fn update_for_user(
        &self,
        _user: &User,
        farm_id: i64,
        attrs: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        if !attrs.is_empty() {
            self.pool.with_write_box(|conn| {
                if let Some(v) = attrs.get("name").and_then(attr_as_str) {
                    conn.execute(
                        "UPDATE farms SET name = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("region").and_then(attr_as_str) {
                    conn.execute(
                        "UPDATE farms SET region = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("latitude").and_then(attr_as_f64) {
                    conn.execute(
                        "UPDATE farms SET latitude = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                if let Some(v) = attrs.get("longitude").and_then(attr_as_f64) {
                    conn.execute(
                        "UPDATE farms SET longitude = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![v, farm_id],
                    )?;
                }
                Ok(())
            })?;
        }
        FarmGateway::find_by_id(self, farm_id)
    }

    fn farm_detail_with_fields(
        &self,
        farm_id: i64,
    ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
        let farm = FarmGateway::find_by_id(self, farm_id)?;
        let fields = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, region, farm_id, user_id, created_at, updated_at \
                 FROM fields WHERE farm_id = ?1 ORDER BY name",
            )?;
            let rows = stmt.query_map(params![farm_id], map_field_row)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })?;
        Ok(FarmDetailOutput::new(farm, fields))
    }

    fn find_delete_usage(
        &self,
        farm_id: i64,
    ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM free_crop_plans WHERE farm_id = ?1",
                params![farm_id],
                |row| row.get(0),
            )?;
            Ok(FarmDeleteUsage::new(count as i32))
        })
    }

    fn soft_delete_with_undo(
        &self,
        user: &User,
        farm_id: i64,
        auto_hide_after: i64,
        toast_message: &str,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        match schedule_destroy(
            &self.pool,
            "Farm",
            farm_id,
            user.id,
            toast_message,
            auto_hide_after,
            Default::default(),
        ) {
            Ok(scheduled) => {
                let farm_name = scheduled
                    .metadata
                    .get("resource_label")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Farm")
                    .to_string();
                Ok(SoftDeleteWithUndoOutcome::Success {
                    undo: json!({
                        "undo_token": scheduled.undo_token,
                        "expires_at": scheduled.expires_at,
                    }),
                    farm_name,
                })
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                Ok(SoftDeleteWithUndoOutcome::Failure(Error::new(err.to_string())))
            }
            Err(err) => Err(err),
        }
    }
}

fn map_field_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FieldEntity> {
    Ok(FieldEntity {
        id: row.get(0)?,
        name: row.get(1)?,
        area: row.get(2)?,
        daily_fixed_cost: row.get(3)?,
        region: row.get(4)?,
        farm_id: row.get(5)?,
        user_id: row.get(6)?,
        created_at: row.get(7)?,
        updated_at: row.get(8)?,
    })
}

fn required_str(attrs: &AttrMap, key: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    attrs
        .get(key)
        .and_then(attr_as_str)
        .map(|s| s.to_string())
        .ok_or_else(|| {
            RecordInvalidError::new(
                Some(format!("{key} is required")),
                None,
            )
        })
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
}

fn required_f64(attrs: &AttrMap, key: &str) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    attrs
        .get(key)
        .and_then(attr_as_f64)
        .ok_or_else(|| {
            RecordInvalidError::new(
                Some(format!("{key} is required")),
                None,
            )
        })
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
}

fn attr_as_str(v: &AttrValue) -> Option<&str> {
    match v {
        AttrValue::Str(s) => Some(s.as_str()),
        _ => None,
    }
}

fn attr_as_f64(v: &AttrValue) -> Option<f64> {
    match v {
        AttrValue::Str(s) => s.parse().ok(),
        AttrValue::Int(i) => Some(*i as f64),
        _ => None,
    }
}

fn attr_as_i64(v: &AttrValue) -> Option<i64> {
    match v {
        AttrValue::Int(i) => Some(*i),
        _ => None,
    }
}

impl PrivatePlanFarmResolveGateway for FarmSqliteGateway {
    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        FarmGateway::find_by_id(self, farm_id)
    }
}
