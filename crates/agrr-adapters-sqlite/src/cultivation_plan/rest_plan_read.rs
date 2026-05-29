//! Ruby: `CultivationPlanRestPlanReadActiveRecordGateway` (per-table reads only).

use crate::pool::SqlitePool;
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct RestPlanHeaderSnapshot {
    pub id: i64,
    pub user_id: Option<i64>,
    pub plan_year: Option<i32>,
    pub plan_name: Option<String>,
    pub display_name: String,
    pub plan_type: String,
    pub status: String,
    pub total_area: f64,
    pub planning_start_date: Option<String>,
    pub planning_end_date: Option<String>,
    pub calculated_planning_start_date: Option<String>,
    pub prediction_target_end_date: Option<String>,
    pub total_profit: f64,
    pub total_revenue: f64,
    pub total_cost: f64,
    pub farm_display_name: String,
    pub farm_region: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RestPlanFieldRowSnapshot {
    pub id: i64,
    pub name: String,
    pub area: f64,
    pub display_name: String,
    pub daily_fixed_cost: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RestPlanCropRowSnapshot {
    pub id: i64,
    pub display_name: String,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RestPlanCultivationRowSnapshot {
    pub id: i64,
    pub cultivation_plan_field_id: Option<i64>,
    pub field_display_name: String,
    pub cultivation_plan_crop_id: Option<i64>,
    pub crop_display_name: String,
    pub area: f64,
    pub start_date: Option<String>,
    pub completion_date: Option<String>,
    pub cultivation_days: Option<i32>,
    pub estimated_cost: Option<f64>,
    pub optimization_result: Option<String>,
    pub status: String,
}

pub struct CultivationPlanRestPlanReadSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanRestPlanReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub fn find_plan_header_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<RestPlanHeaderSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT cp.id, cp.user_id, cp.plan_year, cp.plan_name, cp.plan_type, cp.status, \
                 COALESCE(cp.total_area, 0), cp.planning_start_date, cp.planning_end_date, \
                 COALESCE(f.name, ''), COALESCE(cp.total_profit, 0), COALESCE(cp.total_revenue, 0), \
                 COALESCE(cp.total_cost, 0), COALESCE(f.region, '') \
                 FROM cultivation_plans cp \
                 LEFT JOIN farms f ON f.id = cp.farm_id \
                 WHERE cp.id = ?1 LIMIT 1",
            )?;
            let row = stmt
                .query_row(params![plan_id], |row| {
                    let id: i64 = row.get(0)?;
                    let user_id: Option<i64> = row.get(1)?;
                    let plan_year: Option<i32> = row.get(2)?;
                    let plan_name: Option<String> = row.get(3)?;
                    let plan_type: String = row.get(4)?;
                    let status: String = row.get(5)?;
                    let total_area: f64 = row.get(6)?;
                    let planning_start_date: Option<String> = row.get(7)?;
                    let planning_end_date: Option<String> = row.get(8)?;
                    let farm_display_name: String = row.get(9)?;
                    let total_profit: f64 = row.get(10)?;
                    let total_revenue: f64 = row.get(11)?;
                    let total_cost: f64 = row.get(12)?;
                    let farm_region: String = row.get(13)?;
                    let display_name = compute_plan_display_name(
                        id,
                        plan_name.as_deref(),
                        plan_year,
                        &farm_display_name,
                    );
                    Ok(RestPlanHeaderSnapshot {
                        id,
                        user_id,
                        plan_year,
                        plan_name,
                        display_name,
                        plan_type,
                        status,
                        total_area,
                        planning_start_date: planning_start_date.clone(),
                        planning_end_date: planning_end_date.clone(),
                        calculated_planning_start_date: planning_start_date,
                        prediction_target_end_date: planning_end_date,
                        total_profit,
                        total_revenue,
                        total_cost,
                        farm_display_name,
                        farm_region,
                    })
                })
                .optional()?;
            row.ok_or(rusqlite::Error::QueryReturnedNoRows)
        })
    }

    pub fn list_rest_plan_field_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<RestPlanFieldRowSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.ensure_plan_exists(plan_id)?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, COALESCE(area, 0), COALESCE(daily_fixed_cost, 0) \
                 FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let id: i64 = row.get(0)?;
                let name: String = row.get(1)?;
                let area: f64 = row.get(2)?;
                let display_name = if name.trim().is_empty() {
                    format!("Field #{id}")
                } else {
                    name.clone()
                };
                let daily_fixed_cost: f64 = row.get(3)?;
                Ok(RestPlanFieldRowSnapshot {
                    id,
                    name,
                    area,
                    display_name,
                    daily_fixed_cost,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    pub fn list_rest_plan_crop_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<RestPlanCropRowSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.ensure_plan_exists(plan_id)?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, variety, area_per_unit, revenue_per_area FROM cultivation_plan_crops \
                 WHERE cultivation_plan_id = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let id: i64 = row.get(0)?;
                let name: String = row.get(1)?;
                let variety: Option<String> = row.get(2)?;
                let area_per_unit: Option<f64> = row.get(3)?;
                let revenue_per_area: Option<f64> = row.get(4)?;
                let display_name = crop_display_name_from_parts(&name, variety.as_deref().unwrap_or(""));
                Ok(RestPlanCropRowSnapshot {
                    id,
                    display_name,
                    area_per_unit,
                    revenue_per_area,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    pub fn list_rest_plan_cultivation_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<RestPlanCultivationRowSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.ensure_plan_exists(plan_id)?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT fc.id, fc.cultivation_plan_field_id, fc.cultivation_plan_crop_id, \
                 COALESCE(fc.area, 0), fc.start_date, fc.completion_date, fc.cultivation_days, \
                 fc.estimated_cost, fc.optimization_result, fc.status, \
                 COALESCE(cpf.name, ''), COALESCE(cpc.name, ''), COALESCE(cpc.variety, '') \
                 FROM field_cultivations fc \
                 LEFT JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
                 LEFT JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
                 WHERE fc.cultivation_plan_id = ?1 ORDER BY fc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let id: i64 = row.get(0)?;
                let cultivation_plan_field_id: Option<i64> = row.get(1)?;
                let cultivation_plan_crop_id: Option<i64> = row.get(2)?;
                let area: f64 = row.get(3)?;
                let start_date: Option<String> = row.get(4)?;
                let completion_date: Option<String> = row.get(5)?;
                let cultivation_days: Option<i32> = row.get(6)?;
                let estimated_cost: Option<f64> = row.get(7)?;
                let optimization_result: Option<String> = row.get(8)?;
                let status: String = row.get(9)?;
                let field_name: String = row.get(10)?;
                let crop_name: String = row.get(11)?;
                let crop_variety: String = row.get(12)?;
                let field_display_name = if field_name.trim().is_empty() {
                    cultivation_plan_field_id
                        .map(|fid| format!("Field #{fid}"))
                        .unwrap_or_default()
                } else {
                    field_name
                };
                let crop_display_name = crop_display_name_from_parts(&crop_name, &crop_variety);
                Ok(RestPlanCultivationRowSnapshot {
                    id,
                    cultivation_plan_field_id,
                    field_display_name,
                    cultivation_plan_crop_id,
                    crop_display_name,
                    area,
                    start_date,
                    completion_date,
                    cultivation_days,
                    estimated_cost,
                    optimization_result,
                    status,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    pub fn list_palette_crop_ids_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        self.ensure_plan_exists(plan_id)?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT DISTINCT crop_id FROM cultivation_plan_crops \
                 WHERE cultivation_plan_id = ?1 AND crop_id IS NOT NULL ORDER BY crop_id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| row.get(0))?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn ensure_plan_exists(&self, plan_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let _: i64 = conn.query_row(
                "SELECT 1 FROM cultivation_plans WHERE id = ?1 LIMIT 1",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(())
        })
    }
}

pub(crate) fn compute_plan_display_name(
    id: i64,
    plan_name: Option<&str>,
    plan_year: Option<i32>,
    farm_name: &str,
) -> String {
    let base = plan_name
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.to_string())
        .or_else(|| {
            if !farm_name.trim().is_empty() {
                Some(farm_name.to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| format!("Plan #{id}"));
    if let Some(year) = plan_year {
        format!("{base} ({year})")
    } else {
        base
    }
}

fn crop_display_name_from_parts(name: &str, variety: &str) -> String {
    if variety.trim().is_empty() {
        name.to_string()
    } else {
        format!("{name}（{variety}）")
    }
}

fn parse_opt_date(s: &Option<String>) -> Option<Date> {
    let s = s.as_ref()?;
    Date::parse(s, &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
}

pub(crate) fn field_cultivation_json(fc: &RestPlanCultivationRowSnapshot) -> Value {
    json!({
        "id": fc.id,
        "cultivation_plan_field_id": fc.cultivation_plan_field_id,
        "field_display_name": fc.field_display_name,
        "cultivation_plan_crop_id": fc.cultivation_plan_crop_id,
        "crop_display_name": fc.crop_display_name,
        "start_date": fc.start_date,
        "completion_date": fc.completion_date,
        "cultivation_days": fc.cultivation_days,
        "area": fc.area,
        "estimated_cost": fc.estimated_cost,
        "optimization_profit": null,
    })
}

pub(crate) fn plan_field_json(field: &RestPlanFieldRowSnapshot) -> Value {
    json!({
        "id": field.id,
        "name": field.name,
        "area": field.area,
    })
}

pub(crate) fn private_plan_read_snapshot_from_rest(
    header: RestPlanHeaderSnapshot,
    fields: Vec<RestPlanFieldRowSnapshot>,
    cultivations: Vec<RestPlanCultivationRowSnapshot>,
    palette_crop_ids: Vec<i64>,
) -> agrr_domain::cultivation_plan::dtos::PrivatePlanReadSnapshot {
    let field_cultivations: Vec<Value> = cultivations.iter().map(field_cultivation_json).collect();
    let cultivation_plan_fields: Vec<Value> = fields.iter().map(plan_field_json).collect();
    agrr_domain::cultivation_plan::dtos::PrivatePlanReadSnapshot {
        id: header.id,
        display_name: header.display_name,
        farm_display_name: header.farm_display_name,
        total_area: header.total_area,
        field_cultivations_count: cultivations.len() as i32,
        cultivation_plan_fields_count: fields.len() as i32,
        planning_start_date: parse_opt_date(&header.planning_start_date),
        planning_end_date: parse_opt_date(&header.planning_end_date),
        status: header.status,
        field_cultivations,
        cultivation_plan_fields,
        palette_used_crop_ids: palette_crop_ids,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pool::SqlitePool;

    fn temp_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_cp_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "cp_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (id INTEGER PRIMARY KEY, name TEXT);
                 CREATE TABLE cultivation_plans (
                   id INTEGER PRIMARY KEY, farm_id INTEGER, user_id INTEGER,
                   plan_year INTEGER, plan_name TEXT, plan_type TEXT, status TEXT,
                   total_area REAL, planning_start_date TEXT, planning_end_date TEXT
                 );
                 CREATE TABLE cultivation_plan_fields (
                   id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, name TEXT, area REAL,
                   daily_fixed_cost REAL
                 );
                 CREATE TABLE cultivation_plan_crops (
                   id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER, name TEXT, variety TEXT,
                   crop_id INTEGER
                 );
                 CREATE TABLE field_cultivations (
                   id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER,
                   cultivation_plan_field_id INTEGER, cultivation_plan_crop_id INTEGER,
                   area REAL, start_date TEXT, completion_date TEXT, cultivation_days INTEGER,
                   estimated_cost REAL, optimization_result TEXT, status TEXT
                 );",
            )?;
            conn.execute("INSERT INTO farms (id, name) VALUES (1, 'Farm A')", [])?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, plan_name, plan_type, status, total_area)
                 VALUES (1, 1, 5, 'My Plan', 'private', 'pending', 100.0)",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plan_fields (id, cultivation_plan_id, name, area, daily_fixed_cost)
                 VALUES (10, 1, 'K1', 10.0, 0)",
                [],
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn find_plan_header_missing_returns_not_found() {
        let pool = temp_pool();
        let gw = CultivationPlanRestPlanReadSqliteGateway::new(pool);
        assert!(gw.find_plan_header_snapshot_by_plan_id(999).is_err());
    }

    #[test]
    fn find_plan_header_and_field_rows() {
        let pool = temp_pool();
        let gw = CultivationPlanRestPlanReadSqliteGateway::new(pool);
        let header = gw.find_plan_header_snapshot_by_plan_id(1).unwrap();
        assert_eq!(header.id, 1);
        assert_eq!(header.user_id, Some(5));
        assert_eq!(header.display_name, "My Plan");
        let fields = gw
            .list_rest_plan_field_row_snapshots_by_plan_id(1)
            .unwrap();
        assert_eq!(fields.len(), 1);
        assert_eq!(fields[0].name, "K1");
    }
}
