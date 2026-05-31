//! Ruby: `CultivationPlanActiveRecordGateway` optimize section.

use crate::crop::agrr_requirement::build_crop_agrr_requirement;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    CultivationPlanCropWithAgrr, FieldCultivationCreateAttrs, OptimizationApplyAttrs,
};
use agrr_domain::cultivation_plan::errors::CultivationPlanCropMissingError;
use agrr_domain::cultivation_plan::gateways::CultivationPlanOptimizationGateway;
use rusqlite::{params, OptionalExtension};
use serde_json::Value;

pub struct CultivationPlanOptimizationSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanOptimizationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CultivationPlanOptimizationGateway for CultivationPlanOptimizationSqliteGateway {
    fn field_cultivations_present(
        &self,
        plan_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM field_cultivations WHERE cultivation_plan_id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(count > 0)
        })
    }

    fn field_cultivations_with_allocate_results_present(
        &self,
        plan_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM field_cultivations \
                 WHERE cultivation_plan_id = ?1 \
                   AND cultivation_days > 1 \
                   AND json_extract(optimization_result, '$.raw.growth_days') IS NOT NULL",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(count > 0)
        })
    }

    fn cultivation_plan_crops_with_crop(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanCropWithAgrr>, Box<dyn std::error::Error + Send + Sync>> {
        let rows: Vec<(i64, String, i64, String, Option<f64>)> = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT cpc.id, cpc.name, cpc.crop_id, c.name, c.revenue_per_area \
                 FROM cultivation_plan_crops cpc \
                 INNER JOIN crops c ON c.id = cpc.crop_id \
                 WHERE cpc.cultivation_plan_id = ?1",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, Option<f64>>(4)?,
                ))
            })?;
            rows.collect::<Result<Vec<_>, _>>()
        })?;
        let mut out = Vec::with_capacity(rows.len());
        for (id, name, crop_id, crop_name, revenue_per_area) in rows {
            let agrr_requirement = build_crop_agrr_requirement(&self.pool, crop_id)?
                .ok_or_else(|| format!("crop {crop_id} has no growth stages"))?;
            out.push(CultivationPlanCropWithAgrr::new(
                id,
                name,
                crop_id,
                agrr_requirement,
                revenue_per_area,
                crop_name,
            ));
        }
        Ok(out)
    }

    fn clear_field_cultivations(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "DELETE FROM field_cultivations WHERE cultivation_plan_id = ?1",
                params![plan_id],
            )?;
            Ok(())
        })
    }

    fn create_field_cultivation(
        &self,
        plan_id: i64,
        attrs: FieldCultivationCreateAttrs,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let ar = attrs.to_active_record_attributes();
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO field_cultivations \
                 (cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, \
                  area, start_date, completion_date, cultivation_days, estimated_cost, status, \
                  optimization_result, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, datetime('now'), datetime('now'))",
                params![
                    plan_id,
                    ar.get("cultivation_plan_field_id").and_then(|v| v.as_i64()),
                    ar.get("cultivation_plan_crop_id").and_then(|v| v.as_i64()),
                    ar.get("area").and_then(|v| v.as_f64()),
                    ar.get("start_date").and_then(|v| v.as_str()),
                    ar.get("completion_date").and_then(|v| v.as_str()),
                    ar.get("cultivation_days").and_then(|v| v.as_i64()),
                    ar.get("estimated_cost").and_then(|v| v.as_f64()),
                    ar.get("status").and_then(|v| v.as_str()),
                    ar.get("optimization_result").map(|v| v.to_string()),
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })
    }

    fn upsert_cultivation_plan_field(
        &self,
        plan_id: i64,
        name: &str,
        area: f64,
        daily_fixed_cost: f64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            if let Some(id) = conn
                .query_row(
                    "SELECT id FROM cultivation_plan_fields \
                     WHERE cultivation_plan_id = ?1 AND name = ?2 LIMIT 1",
                    params![plan_id, name],
                    |row| row.get::<_, i64>(0),
                )
                .optional()?
            {
                return Ok(id);
            }
            conn.execute(
                "INSERT INTO cultivation_plan_fields \
                 (cultivation_plan_id, name, area, daily_fixed_cost, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, datetime('now'), datetime('now'))",
                params![plan_id, name, area, daily_fixed_cost],
            )?;
            Ok(conn.last_insert_rowid())
        })
    }

    fn find_crop_id(
        &self,
        plan_id: i64,
        crop_id: i64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let found: Option<i64> = self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id FROM cultivation_plan_crops \
                 WHERE cultivation_plan_id = ?1 AND crop_id = ?2 LIMIT 1",
                params![plan_id, crop_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()
        })?;
        if let Some(id) = found {
            return Ok(id);
        }
        let available: Vec<(i64, String)> = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT crop_id, name FROM cultivation_plan_crops WHERE cultivation_plan_id = ?1",
            )?;
            let rows = stmt.query_map(params![plan_id], |r| Ok((r.get(0)?, r.get(1)?)))?;
            rows.collect()
        })?;
        Err(Box::new(CultivationPlanCropMissingError::new(format!(
            "CultivationPlanCrop not found for crop_id: {crop_id}. Available: {available:?}"
        ))))
    }

    fn apply_optimization_result(
        &self,
        plan_id: i64,
        attrs: OptimizationApplyAttrs,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE cultivation_plans SET \
                 total_profit = ?1, total_revenue = ?2, total_cost = ?3, \
                 optimization_time = ?4, algorithm_used = ?5, is_optimal = ?6, \
                 optimization_summary = ?7, updated_at = datetime('now') \
                 WHERE id = ?8",
                params![
                    attrs.total_profit,
                    attrs.total_revenue,
                    attrs.total_cost,
                    attrs.optimization_time,
                    attrs.algorithm_used,
                    if attrs.is_optimal { 1i64 } else { 0i64 },
                    attrs.optimization_summary,
                    plan_id,
                ],
            )?;
            Ok(())
        })
    }

    fn update_predicted_weather_data(
        &self,
        cultivation_plan_id: i64,
        payload: Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let json = payload.to_string();
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE cultivation_plans SET predicted_weather_data = ?1, updated_at = datetime('now') WHERE id = ?2",
                params![json, cultivation_plan_id],
            )?;
            Ok(())
        })
    }
}

#[cfg(test)]
mod cultivation_plan_optimization_sqlite_gateway_test {
    use super::*;
    use crate::pool::SqlitePool;
    use agrr_domain::cultivation_plan::gateways::CultivationPlanOptimizationGateway;
    use std::fs;
    use std::path::PathBuf;

    fn temp_db() -> (SqlitePool, PathBuf) {
        let dir = std::env::temp_dir().join(format!("agrr-opt-gw-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test.sqlite3");
        let _ = fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE cultivation_plans (id INTEGER PRIMARY KEY, total_area REAL);
                 CREATE TABLE cultivation_plan_fields (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   cultivation_plan_id INTEGER NOT NULL,
                   name TEXT NOT NULL,
                   area REAL NOT NULL,
                   daily_fixed_cost REAL NOT NULL,
                   created_at TEXT,
                   updated_at TEXT
                 );",
            )
        })
        .unwrap();
        (pool, path)
    }

    #[test]
    fn upsert_field_does_not_update_existing_area() {
        let (pool, path) = temp_db();
        let gw = CultivationPlanOptimizationSqliteGateway::new(pool.clone());
        pool.with_write(|conn| {
            conn.execute("INSERT INTO cultivation_plans (id, total_area) VALUES (1, 100)", [])
        })
        .unwrap();
        pool.with_write(|conn| {
            conn.execute(
                "INSERT INTO cultivation_plan_fields (cultivation_plan_id, name, area, daily_fixed_cost) VALUES (1, '1', 50.0, 10.0)",
                [],
            )
        })
        .unwrap();
        let id1 = gw.upsert_cultivation_plan_field(1, "1", 99.0, 10.0).unwrap();
        let id2 = gw.upsert_cultivation_plan_field(1, "1", 99.0, 10.0).unwrap();
        assert_eq!(id1, id2);
        let area: f64 = pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT area FROM cultivation_plan_fields WHERE id = ?1",
                    rusqlite::params![id1],
                    |row| row.get(0),
                )
            })
            .unwrap();
        assert!((area - 50.0).abs() < 0.001, "area must stay 50.0, got {area}");
        let _ = fs::remove_file(path);
    }
}
