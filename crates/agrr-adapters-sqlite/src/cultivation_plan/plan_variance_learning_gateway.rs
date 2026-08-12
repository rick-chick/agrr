//! SQLite persistence for plan variance learning snapshots.

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    PlanVarianceLearningSnapshotRead, PlanVsActualCategorySummaryRead, PlanVsActualItemRead,
    PlanVsActualSummaryRead,
};
use agrr_domain::cultivation_plan::gateways::PlanVarianceLearningGateway;
use rusqlite::params;
use serde_json::{json, Value};

pub struct PlanVarianceLearningSqliteGateway {
    pool: SqlitePool,
}

impl PlanVarianceLearningSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl PlanVarianceLearningGateway for PlanVarianceLearningSqliteGateway {
    fn save(
        &self,
        plan_id: i64,
        source_plan_id: i64,
        summary: &PlanVsActualSummaryRead,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let snapshot_json = summary_to_json(summary);
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO plan_variance_learning_snapshots \
                 (plan_id, source_plan_id, snapshot_json, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, datetime('now'), datetime('now')) \
                 ON CONFLICT(plan_id) DO UPDATE SET \
                   source_plan_id = excluded.source_plan_id, \
                   snapshot_json = excluded.snapshot_json, \
                   updated_at = datetime('now')",
                params![plan_id, source_plan_id, snapshot_json],
            )?;
            Ok(())
        })
    }

    fn find_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT source_plan_id, snapshot_json \
                 FROM plan_variance_learning_snapshots WHERE plan_id = ?1 LIMIT 1",
            )?;
            let result = stmt.query_row(params![plan_id], |row| {
                let source_plan_id: i64 = row.get(0)?;
                let snapshot_json: String = row.get(1)?;
                Ok((source_plan_id, snapshot_json))
            });
            match result {
                Ok((source_plan_id, snapshot_json)) => {
                    let summary = summary_from_json(plan_id, &snapshot_json)
                        .map_err(|err| rusqlite::Error::ToSqlConversionFailure(err))?;
                    Ok(Some(PlanVarianceLearningSnapshotRead {
                        plan_id,
                        source_plan_id,
                        summary,
                    }))
                }
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(err) => Err(err),
            }
        })
    }
}

fn summary_to_json(summary: &PlanVsActualSummaryRead) -> String {
    let body = json!({
        "plan_id": summary.plan_id,
        "unrecorded_count": summary.unrecorded_count,
        "categories": summary.categories.iter().map(|category| json!({
            "category": category.category,
            "average_delta_days": category.average_delta_days,
            "item_count": category.item_count,
            "recorded_count": category.recorded_count,
        })).collect::<Vec<_>>(),
        "top_variance_items": summary.top_variance_items.iter().map(|item| json!({
            "item_id": item.item_id,
            "field_cultivation_id": item.field_cultivation_id,
            "category": item.category,
            "name": item.name,
            "scheduled_date": item.scheduled_date,
            "actual_date": item.actual_date,
            "delta_days": item.delta_days,
            "gdd_trigger": item.gdd_trigger,
            "gdd_at_actual": item.gdd_at_actual,
            "gdd_delta": item.gdd_delta,
        })).collect::<Vec<_>>(),
    });
    body.to_string()
}

fn summary_from_json(
    plan_id: i64,
    snapshot_json: &str,
) -> Result<PlanVsActualSummaryRead, Box<dyn std::error::Error + Send + Sync>> {
    let value: Value = serde_json::from_str(snapshot_json)?;
    let categories = value["categories"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|category| PlanVsActualCategorySummaryRead {
            category: category["category"].as_str().unwrap_or_default().to_string(),
            average_delta_days: category["average_delta_days"].as_f64(),
            item_count: category["item_count"].as_i64().unwrap_or(0),
            recorded_count: category["recorded_count"].as_i64().unwrap_or(0),
        })
        .collect();
    let top_variance_items = value["top_variance_items"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|item| PlanVsActualItemRead {
            item_id: item["item_id"].as_i64().unwrap_or(0),
            field_cultivation_id: item["field_cultivation_id"].as_i64().unwrap_or(0),
            category: item["category"].as_str().unwrap_or_default().to_string(),
            name: item["name"].as_str().unwrap_or_default().to_string(),
            scheduled_date: item["scheduled_date"].as_str().map(str::to_string),
            actual_date: item["actual_date"].as_str().map(str::to_string),
            delta_days: item["delta_days"].as_i64(),
            gdd_trigger: item["gdd_trigger"].as_f64(),
            gdd_at_actual: item["gdd_at_actual"].as_f64(),
            gdd_delta: item["gdd_delta"].as_f64(),
        })
        .collect();

    Ok(PlanVsActualSummaryRead {
        plan_id: value["plan_id"].as_i64().unwrap_or(plan_id),
        unrecorded_count: value["unrecorded_count"].as_i64().unwrap_or(0),
        categories,
        top_variance_items,
    })
}

#[cfg(test)]
mod plan_variance_learning_sqlite_gateway_test {
    use super::*;
    use crate::pool::SqlitePool;

    fn test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!(
            "agrr_plan_variance_learning_gw_{}",
            std::process::id()
        ));
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join(format!(
            "variance_learning_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().expect("utf8 path"));
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE plan_variance_learning_snapshots (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   plan_id INTEGER NOT NULL UNIQUE,
                   source_plan_id INTEGER NOT NULL,
                   snapshot_json TEXT NOT NULL,
                   created_at TEXT NOT NULL DEFAULT (datetime('now')),
                   updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                 );",
            )
        })
        .expect("schema");
        pool
    }

    #[test]
    fn save_and_find_round_trip() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);
        let summary = PlanVsActualSummaryRead {
            plan_id: 20,
            unrecorded_count: 1,
            categories: vec![PlanVsActualCategorySummaryRead {
                category: "general".into(),
                average_delta_days: Some(3.0),
                item_count: 2,
                recorded_count: 1,
            }],
            top_variance_items: vec![],
        };

        gateway.save(20, 10, &summary).expect("save");
        let found = gateway
            .find_by_plan_id(20)
            .expect("find")
            .expect("snapshot");
        assert_eq!(20, found.plan_id);
        assert_eq!(10, found.source_plan_id);
        assert_eq!(1, found.summary.unrecorded_count);
        assert_eq!(Some(3.0), found.summary.categories[0].average_delta_days);
    }
}
