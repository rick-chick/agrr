//! Ruby: `InteractionRuleActiveRecordGateway#list_by_cultivation_plan_id`

use crate::interaction_rule::interaction_rule_gateway::InteractionRuleSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::gateways::InteractionRulePlanReadGateway;
use agrr_domain::interaction_rule::entities::InteractionRuleEntity;
use rusqlite::params;

pub struct InteractionRulePlanReadSqliteGateway {
    pool: SqlitePool,
}

impl InteractionRulePlanReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl InteractionRulePlanReadGateway for InteractionRulePlanReadSqliteGateway {
    fn list_by_cultivation_plan_id(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let (user_id, region): (Option<i64>, String) = conn.query_row(
                "SELECT cp.user_id, f.region FROM cultivation_plans cp \
                 INNER JOIN farms f ON f.id = cp.farm_id WHERE cp.id = ?1",
                params![cultivation_plan_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )?;

            let mut out = Vec::new();
            if let Some(uid) = user_id {
                let mut stmt = conn.prepare(
                    "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, \
                     is_directional, description, region, is_reference, created_at, updated_at \
                     FROM interaction_rules \
                     WHERE ((user_id = ?1 AND is_reference = 0) OR is_reference = 1) AND region = ?2",
                )?;
                let rows = stmt.query_map(params![uid, region], InteractionRuleSqliteGateway::row_to_entity)?;
                for r in rows {
                    out.push(r?);
                }
            } else {
                let mut stmt = conn.prepare(
                    "SELECT id, user_id, rule_type, source_group, target_group, impact_ratio, \
                     is_directional, description, region, is_reference, created_at, updated_at \
                     FROM interaction_rules WHERE is_reference = 1 AND region = ?1",
                )?;
                let rows = stmt.query_map(params![region], InteractionRuleSqliteGateway::row_to_entity)?;
                for r in rows {
                    out.push(r?);
                }
            }
            Ok(out)
        })
    }
}
