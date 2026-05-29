//! Ruby: `CultivationPlanFieldMutationActiveRecordGateway` — P6 public plan create slice.

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::CultivationPlanFieldSnapshot;
use agrr_domain::cultivation_plan::gateways::CultivationPlanFieldMutationGateway;
use rusqlite::{params, OptionalExtension};

pub struct CultivationPlanFieldMutationSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanFieldMutationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn unsupported(method: &str) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        format!("{method} not supported in P6 field mutation write slice"),
    ))
}

impl CultivationPlanFieldMutationGateway for CultivationPlanFieldMutationSqliteGateway {
    fn count_fields(
        &self,
        plan_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(count as i32)
        })
    }

    fn find_field(
        &self,
        plan_id: i64,
        field_id: i64,
    ) -> Result<Option<CultivationPlanFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            let row = conn
                .query_row(
                    "SELECT cpf.id, cpf.name, cpf.area, \
                     (SELECT COUNT(*) FROM field_cultivations fc WHERE fc.cultivation_plan_field_id = cpf.id) \
                     FROM cultivation_plan_fields cpf \
                     WHERE cpf.cultivation_plan_id = ?1 AND cpf.id = ?2",
                    params![plan_id, field_id],
                    |row| {
                        Ok(CultivationPlanFieldSnapshot {
                            id: row.get(0)?,
                            name: row.get(1)?,
                            area: row.get(2)?,
                            cultivation_count: row.get(3)?,
                        })
                    },
                )
                .optional()?;
            Ok(row)
        })
    }

    fn create_field(
        &self,
        plan_id: i64,
        field_name: &str,
        field_area: f64,
        daily_fixed_cost: Option<f64>,
    ) -> Result<CultivationPlanFieldSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO cultivation_plan_fields \
                 (cultivation_plan_id, name, area, daily_fixed_cost, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, datetime('now'), datetime('now'))",
                params![plan_id, field_name, field_area, daily_fixed_cost],
            )?;
            let id = conn.last_insert_rowid();
            Ok(CultivationPlanFieldSnapshot::new(id, field_name, field_area))
        })
    }

    fn delete_field(
        &self,
        plan_id: i64,
        field_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let deleted = conn.execute(
                "DELETE FROM cultivation_plan_fields WHERE id = ?1 AND cultivation_plan_id = ?2",
                params![field_id, plan_id],
            )?;
            if deleted == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok(())
        })
    }

    fn refresh_total_area(
        &self,
        plan_id: i64,
    ) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let total: f64 = conn.query_row(
                "SELECT COALESCE(SUM(area), 0) FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            conn.execute(
                "UPDATE cultivation_plans SET total_area = ?1, updated_at = datetime('now') WHERE id = ?2",
                params![total, plan_id],
            )?;
            Ok(total)
        })
    }
}
