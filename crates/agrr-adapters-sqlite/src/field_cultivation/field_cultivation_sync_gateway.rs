//! Ruby: `FieldCultivationSyncActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::field_cultivation::dtos::{FieldCultivationSyncApply, FieldCultivationSyncDesiredRow};
use agrr_domain::field_cultivation::gateways::FieldCultivationSyncGateway;
use agrr_domain::shared::ports::logger_port::LoggerPort;
use rusqlite::params;
use time::OffsetDateTime;

pub struct FieldCultivationSyncSqliteGateway {
    pool: SqlitePool,
    logger: Box<dyn LoggerPort>,
}

impl FieldCultivationSyncSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            pool,
            logger: Box::new(NoopSyncLogger),
        }
    }

    pub fn with_logger(pool: SqlitePool, logger: Box<dyn LoggerPort>) -> Self {
        Self { pool, logger }
    }
}

struct NoopSyncLogger;

impl LoggerPort for NoopSyncLogger {
    fn info(&self, _message: &str) {}
    fn warn(&self, _message: &str) {}
    fn error(&self, _message: &str) {}
    fn debug(&self, _message: &str) {}
}

fn date_str(d: time::Date) -> String {
    d.to_string()
}

fn row_area(area: Option<f64>) -> f64 {
    area.unwrap_or(0.0)
}

fn optimization_result_json(value: &serde_json::Value) -> String {
    value.to_string()
}

fn update_field_cultivation(
    conn: &rusqlite::Connection,
    plan_id: i64,
    row: &FieldCultivationSyncDesiredRow,
    now: &str,
) -> rusqlite::Result<usize> {
    let fc_id = row
        .field_cultivation_id
        .expect("update row requires field_cultivation_id");
    conn.execute(
        "UPDATE field_cultivations SET \
         cultivation_plan_id = ?1, cultivation_plan_field_id = ?2, cultivation_plan_crop_id = ?3, \
         start_date = ?4, completion_date = ?5, cultivation_days = ?6, area = ?7, \
         estimated_cost = ?8, optimization_result = ?9, updated_at = ?10 \
         WHERE id = ?11 AND cultivation_plan_id = ?1",
        params![
            plan_id,
            row.cultivation_plan_field_id,
            row.cultivation_plan_crop_id,
            date_str(row.start_date),
            date_str(row.completion_date),
            row.cultivation_days,
            row_area(row.area),
            row.estimated_cost,
            optimization_result_json(&row.optimization_result),
            now,
            fc_id,
        ],
    )
}

fn insert_field_cultivation(
    conn: &rusqlite::Connection,
    plan_id: i64,
    row: &FieldCultivationSyncDesiredRow,
    now: &str,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO field_cultivations \
         (cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, \
          start_date, completion_date, cultivation_days, area, estimated_cost, \
          optimization_result, status, created_at, updated_at) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 'pending', ?10, ?10)",
        params![
            plan_id,
            row.cultivation_plan_field_id,
            row.cultivation_plan_crop_id,
            date_str(row.start_date),
            date_str(row.completion_date),
            row.cultivation_days,
            row_area(row.area),
            row.estimated_cost,
            optimization_result_json(&row.optimization_result),
            now,
        ],
    )?;
    Ok(())
}

impl FieldCultivationSyncGateway for FieldCultivationSyncSqliteGateway {
    fn sync_by_plan_id(
        &self,
        plan_id: i64,
        sync_apply: &FieldCultivationSyncApply,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.logger.info(&format!(
            "💾 [FieldCultivationSync] updates={} creates={} deletes={}",
            sync_apply.field_cultivations_to_update.len(),
            sync_apply.field_cultivations_to_create.len(),
            sync_apply.field_cultivation_ids_to_delete.len(),
        ));

        self.pool.with_write_box(|conn| {
            conn.execute("BEGIN IMMEDIATE", [])?;

            let exists: Option<i64> = conn
                .query_row(
                    "SELECT id FROM cultivation_plans WHERE id = ?1",
                    params![plan_id],
                    |row| row.get(0),
                )
                .ok();
            if exists.is_none() {
                let _ = conn.execute("ROLLBACK", []);
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }

            let now = OffsetDateTime::now_utc()
                .format(&time::format_description::well_known::Rfc3339)
                .unwrap_or_else(|_| "datetime('now')".into());

            for row in &sync_apply.field_cultivations_to_update {
                update_field_cultivation(conn, plan_id, row, &now)?;
            }

            for row in &sync_apply.field_cultivations_to_create {
                insert_field_cultivation(conn, plan_id, row, &now)?;
            }

            if !sync_apply.field_cultivation_ids_to_delete.is_empty() {
                for fc_id in &sync_apply.field_cultivation_ids_to_delete {
                    conn.execute(
                        "UPDATE task_schedules SET field_cultivation_id = NULL, updated_at = ?1 \
                         WHERE field_cultivation_id = ?2",
                        params![now, fc_id],
                    )?;
                    conn.execute(
                        "DELETE FROM field_cultivations WHERE id = ?1 AND cultivation_plan_id = ?2",
                        params![fc_id, plan_id],
                    )?;
                }
            }

            if !sync_apply.cultivation_plan_crop_ids_to_delete.is_empty() {
                self.logger.info(&format!(
                    "🗑️ [FieldCultivationSync] 未参照 plan_crop 削除: {}件",
                    sync_apply.cultivation_plan_crop_ids_to_delete.len()
                ));
                for cpc_id in &sync_apply.cultivation_plan_crop_ids_to_delete {
                    conn.execute(
                        "DELETE FROM cultivation_plan_crops WHERE id = ?1 AND cultivation_plan_id = ?2",
                        params![cpc_id, plan_id],
                    )?;
                }
            }

            let summary = &sync_apply.cultivation_plan_summary;
            conn.execute(
                "UPDATE cultivation_plans SET \
                 optimization_summary = ?1, total_profit = ?2, total_revenue = ?3, total_cost = ?4, \
                 optimization_time = ?5, algorithm_used = ?6, is_optimal = ?7, status = 'completed', \
                 updated_at = ?8 \
                 WHERE id = ?9",
                params![
                    summary.optimization_summary,
                    summary.total_profit,
                    summary.total_revenue,
                    summary.total_cost,
                    summary.optimization_time,
                    summary.algorithm_used,
                    summary.is_optimal.map(|b| if b { 1i64 } else { 0i64 }),
                    now,
                    plan_id,
                ],
            )?;

            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM field_cultivations WHERE cultivation_plan_id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            self.logger.info(&format!(
                "📊 [FieldCultivationSync] 完了: field_cultivations={count}"
            ));

            conn.execute("COMMIT", [])?;
            Ok(())
        })
    }
}
