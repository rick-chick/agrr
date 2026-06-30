//! Ruby: `CultivationPlanPrivateReadActiveRecordGateway` (index rows + counts).

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::PrivatePlanIndexPlanRow;
use agrr_domain::cultivation_plan::gateways::CultivationPlanPrivateReadGateway;
use rusqlite::params;

pub struct CultivationPlanPrivateReadSqliteGateway {
    pool: SqlitePool,
}

impl CultivationPlanPrivateReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CultivationPlanPrivateReadGateway for CultivationPlanPrivateReadSqliteGateway {
    fn list_private_plan_index_rows_by_user_id(
        &self,
        user_id: i64,
    ) -> Result<Vec<PrivatePlanIndexPlanRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read(|conn| {
            let mut stmt = conn.prepare(
                "SELECT cp.id, cp.farm_id, COALESCE(f.name, ''), COALESCE(cp.total_area, 0), cp.status, \
                 COALESCE(cp.plan_name, ''), cp.created_at, \
                 (SELECT COUNT(*) FROM cultivation_plan_crops cpc WHERE cpc.cultivation_plan_id = cp.id), \
                 (SELECT COUNT(*) FROM cultivation_plan_fields cpf WHERE cpf.cultivation_plan_id = cp.id) \
                 FROM cultivation_plans cp \
                 LEFT JOIN farms f ON f.id = cp.farm_id \
                 WHERE cp.user_id = ?1 AND cp.plan_type = 'private' \
                 ORDER BY cp.updated_at DESC",
            )?;
            let rows = stmt.query_map(params![user_id], |row| {
                let id: i64 = row.get(0)?;
                let farm_id: i64 = row.get(1)?;
                let farm_display_name: String = row.get(2)?;
                let total_area: f64 = row.get(3)?;
                let status: String = row.get(4)?;
                let plan_name: String = row.get(5)?;
                let created_at: String = row.get(6)?;
                let crops_count: i32 = row.get(7)?;
                let fields_count: i32 = row.get(8)?;
                let display_name = if plan_name.trim().is_empty() {
                    format!("Plan #{id}")
                } else {
                    plan_name
                };
                Ok(PrivatePlanIndexPlanRow {
                    id,
                    farm_id,
                    farm_display_name,
                    total_area,
                    crops_count,
                    fields_count,
                    status,
                    display_name,
                    created_at,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }
}
