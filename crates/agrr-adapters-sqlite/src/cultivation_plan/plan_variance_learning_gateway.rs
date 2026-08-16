//! SQLite persistence for plan variance learning snapshots.

use std::collections::BTreeMap;

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    BlueprintTimingAdjustmentProposalRead, LearnHandoffStatePatch, LearnHandoffStateRead,
    PlanVarianceActionItemRead, PlanVarianceLearningSnapshotRead, PlanVsActualCategorySummaryRead,
    PlanVsActualItemRead, PlanVsActualSummaryRead, StageGddCalibrationProposalRead,
    ReorganizeOrchestrationProgressPatch, ReorganizeOrchestrationProgressRead,
};
use agrr_domain::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;
use agrr_domain::cultivation_plan::gateways::PlanVarianceLearningGateway;
use rusqlite::params;
use serde_json::{json, Map, Value};

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
                        source_plan_id: Some(source_plan_id),
                        summary: Some(summary),
                        proposal_application_progress: BTreeMap::new(),
                        reorganize_orchestration_progress: ReorganizeOrchestrationProgressRead::default(),
                        learn_handoff: LearnHandoffStateRead::default(),
                    }))
                }
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(err) => Err(err),
            }
        })
    }

    fn find_proposal_application_progress_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT proposal_key, status \
                 FROM plan_variance_learning_proposal_states WHERE plan_id = ?1",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })?;
            let mut map = BTreeMap::new();
            for row in rows {
                let (key, status) = row?;
                map.insert(key, status);
            }
            Ok(map)
        })
    }

    fn upsert_proposal_application_progress(
        &self,
        plan_id: i64,
        updates: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            for (proposal_key, status) in updates {
                conn.execute(
                    "INSERT INTO plan_variance_learning_proposal_states \
                     (plan_id, proposal_key, status, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, datetime('now'), datetime('now')) \
                     ON CONFLICT(plan_id, proposal_key) DO UPDATE SET \
                       status = excluded.status, \
                       updated_at = datetime('now')",
                    params![plan_id, proposal_key, status],
                )?;
            }
            Ok(())
        })
    }

    fn find_reorganize_orchestration_progress_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<ReorganizeOrchestrationProgressRead, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT placement_complete, regenerate_complete, sync_verify_complete, return_to_learn, \
                 pipeline_active, current_phase, last_error \
                 FROM plan_variance_learning_orchestration_steps WHERE plan_id = ?1 LIMIT 1",
            )?;
            let result = stmt.query_row(params![plan_id], |row| {
                Ok(ReorganizeOrchestrationProgressRead {
                    placement: row.get::<_, i64>(0)? != 0,
                    regenerate: row.get::<_, i64>(1)? != 0,
                    sync_verify: row.get::<_, i64>(2)? != 0,
                    return_to_learn: row.get::<_, i64>(3)? != 0,
                    pipeline_active: row.get::<_, i64>(4)? != 0,
                    current_phase: row.get(5)?,
                    last_error: row.get(6)?,
                })
            });
            match result {
                Ok(progress) => Ok(progress),
                Err(rusqlite::Error::QueryReturnedNoRows) => {
                    Ok(ReorganizeOrchestrationProgressRead::default())
                }
                Err(err) => Err(err),
            }
        })
    }

    fn upsert_reorganize_orchestration_progress(
        &self,
        plan_id: i64,
        updates: &ReorganizeOrchestrationProgressPatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let current = {
                let mut stmt = conn.prepare(
                    "SELECT placement_complete, regenerate_complete, sync_verify_complete, return_to_learn, \
                     pipeline_active, current_phase, last_error \
                     FROM plan_variance_learning_orchestration_steps WHERE plan_id = ?1 LIMIT 1",
                )?;
                let result = stmt.query_row(params![plan_id], |row| {
                    Ok(ReorganizeOrchestrationProgressRead {
                        placement: row.get::<_, i64>(0)? != 0,
                        regenerate: row.get::<_, i64>(1)? != 0,
                        sync_verify: row.get::<_, i64>(2)? != 0,
                        return_to_learn: row.get::<_, i64>(3)? != 0,
                        pipeline_active: row.get::<_, i64>(4)? != 0,
                        current_phase: row.get(5)?,
                        last_error: row.get(6)?,
                    })
                });
                match result {
                    Ok(progress) => progress,
                    Err(rusqlite::Error::QueryReturnedNoRows) => {
                        ReorganizeOrchestrationProgressRead::default()
                    }
                    Err(err) => return Err(err.into()),
                }
            };

            let placement = updates.placement.unwrap_or(current.placement);
            let regenerate = updates.regenerate.unwrap_or(current.regenerate);
            let sync_verify = updates.sync_verify.unwrap_or(current.sync_verify);
            let return_to_learn = updates.return_to_learn.unwrap_or(current.return_to_learn);
            let pipeline_active = updates.pipeline_active.unwrap_or(current.pipeline_active);
            let current_phase = updates
                .current_phase
                .clone()
                .unwrap_or(current.current_phase);
            let last_error = match &updates.last_error {
                None => current.last_error.clone(),
                Some(None) => None,
                Some(Some(message)) => Some(message.clone()),
            };

            conn.execute(
                "INSERT INTO plan_variance_learning_orchestration_steps \
                 (plan_id, placement_complete, regenerate_complete, sync_verify_complete, return_to_learn, \
                  pipeline_active, current_phase, last_error, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, datetime('now'), datetime('now')) \
                 ON CONFLICT(plan_id) DO UPDATE SET \
                   placement_complete = excluded.placement_complete, \
                   regenerate_complete = excluded.regenerate_complete, \
                   sync_verify_complete = excluded.sync_verify_complete, \
                   return_to_learn = excluded.return_to_learn, \
                   pipeline_active = excluded.pipeline_active, \
                   current_phase = excluded.current_phase, \
                   last_error = excluded.last_error, \
                   updated_at = datetime('now')",
                params![
                    plan_id,
                    placement as i64,
                    regenerate as i64,
                    sync_verify as i64,
                    return_to_learn as i64,
                    pipeline_active as i64,
                    current_phase,
                    last_error,
                ],
            )?;
            Ok(())
        })
    }

    fn find_learn_handoff_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<LearnHandoffStateRead, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT handoff_json \
                 FROM plan_variance_learning_handoff_states WHERE plan_id = ?1 LIMIT 1",
            )?;
            let result = stmt.query_row(params![plan_id], |row| {
                let handoff_json: String = row.get(0)?;
                Ok(handoff_json)
            });
            match result {
                Ok(json) => learn_handoff_from_json(&json)
                    .map_err(|err| rusqlite::Error::ToSqlConversionFailure(err)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(LearnHandoffStateRead::default()),
                Err(err) => Err(err),
            }
        })
    }

    fn patch_learn_handoff(
        &self,
        plan_id: i64,
        patch: &LearnHandoffStatePatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let current = {
                let mut stmt = conn.prepare(
                    "SELECT handoff_json \
                     FROM plan_variance_learning_handoff_states WHERE plan_id = ?1 LIMIT 1",
                )?;
                let result = stmt.query_row(params![plan_id], |row| {
                    let handoff_json: String = row.get(0)?;
                    Ok(handoff_json)
                });
                match result {
                    Ok(json) => learn_handoff_from_json(&json)
                        .map_err(|err| rusqlite::Error::ToSqlConversionFailure(err))?,
                    Err(rusqlite::Error::QueryReturnedNoRows) => LearnHandoffStateRead::default(),
                    Err(err) => return Err(err.into()),
                }
            };

            let mut next = current;
            if let Some(post_master_payload) = &patch.post_master_payload {
                next.post_master_payload = post_master_payload.clone();
            }
            if let Some(bp_timing_apply_context) = &patch.bp_timing_apply_context {
                next.bp_timing_apply_context = bp_timing_apply_context.clone();
            }
            if let Some(crop_id) = patch.blueprint_prefill_crop_id {
                let key = crop_id.to_string();
                match &patch.blueprint_prefill_body {
                    Some(Some(body)) => {
                        next.blueprint_prefill_by_crop_id.insert(key, body.clone());
                    }
                    Some(None) => {
                        next.blueprint_prefill_by_crop_id.remove(&key);
                    }
                    None => {}
                }
            }

            let handoff_json = learn_handoff_to_json(&next)
                .map_err(|err| rusqlite::Error::ToSqlConversionFailure(err))?;
            conn.execute(
                "INSERT INTO plan_variance_learning_handoff_states \
                 (plan_id, handoff_json, created_at, updated_at) \
                 VALUES (?1, ?2, datetime('now'), datetime('now')) \
                 ON CONFLICT(plan_id) DO UPDATE SET \
                   handoff_json = excluded.handoff_json, \
                   updated_at = datetime('now')",
                params![plan_id, handoff_json],
            )?;
            Ok(())
        })
    }
}

fn learn_handoff_from_json(
    handoff_json: &str,
) -> Result<LearnHandoffStateRead, Box<dyn std::error::Error + Send + Sync>> {
    let value: Value = serde_json::from_str(handoff_json)?;
    let blueprint_prefill = value
        .get("blueprint_prefill_by_crop_id")
        .and_then(|v| v.as_object())
        .map(|map| {
            map.iter()
                .filter_map(|(key, body)| body.as_object().map(|_| (key.clone(), body.clone())))
                .collect()
        })
        .unwrap_or_default();

    Ok(LearnHandoffStateRead {
        post_master_payload: value.get("post_master_payload").cloned(),
        bp_timing_apply_context: value.get("bp_timing_apply_context").cloned(),
        blueprint_prefill_by_crop_id: blueprint_prefill,
    })
}

fn learn_handoff_to_json(
    handoff: &LearnHandoffStateRead,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    let mut body = Map::new();
    if let Some(payload) = &handoff.post_master_payload {
        body.insert("post_master_payload".into(), payload.clone());
    }
    if let Some(context) = &handoff.bp_timing_apply_context {
        body.insert("bp_timing_apply_context".into(), context.clone());
    }
    if !handoff.blueprint_prefill_by_crop_id.is_empty() {
        body.insert(
            "blueprint_prefill_by_crop_id".into(),
            Value::Object(
                handoff
                    .blueprint_prefill_by_crop_id
                    .iter()
                    .map(|(key, value)| (key.clone(), value.clone()))
                    .collect(),
            ),
        );
    }
    Ok(Value::Object(body).to_string())
}

fn summary_to_json(summary: &PlanVsActualSummaryRead) -> String {
    let body = json!({
        "plan_id": summary.plan_id,
        "unrecorded_count": summary.unrecorded_count,
        "structured_unrecorded_count": summary.structured_unrecorded_count,
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
        "stage_gdd_calibration_proposals": summary
            .stage_gdd_calibration_proposals
            .iter()
            .map(|proposal| json!({
                "crop_id": proposal.crop_id,
                "crop_name": proposal.crop_name,
                "stage_order": proposal.stage_order,
                "stage_name": proposal.stage_name,
                "average_gdd_delta": proposal.average_gdd_delta,
                "recorded_item_count": proposal.recorded_item_count,
            }))
            .collect::<Vec<_>>(),
        "action_required_items": summary
            .action_required_items
            .iter()
            .map(|item| json!({
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
                "exceedance_kind": item.exceedance_kind.as_str(),
            }))
            .collect::<Vec<_>>(),
        "blueprint_timing_adjustment_proposals": summary
            .blueprint_timing_adjustment_proposals
            .iter()
            .map(|proposal| json!({
                "crop_id": proposal.crop_id,
                "crop_name": proposal.crop_name,
                "category": proposal.category,
                "average_delta_days": proposal.average_delta_days,
                "average_gdd_delta": proposal.average_gdd_delta,
                "recorded_item_count": proposal.recorded_item_count,
            }))
            .collect::<Vec<_>>(),
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
    let stage_gdd_calibration_proposals = value["stage_gdd_calibration_proposals"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|proposal| StageGddCalibrationProposalRead {
            crop_id: proposal["crop_id"].as_i64().unwrap_or(0),
            crop_name: proposal["crop_name"].as_str().unwrap_or_default().to_string(),
            stage_order: proposal["stage_order"].as_i64().unwrap_or(0) as i32,
            stage_name: proposal["stage_name"].as_str().unwrap_or_default().to_string(),
            average_gdd_delta: proposal["average_gdd_delta"].as_f64().unwrap_or(0.0),
            recorded_item_count: proposal["recorded_item_count"].as_i64().unwrap_or(0),
        })
        .collect();
    let action_required_items = value["action_required_items"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|item| PlanVarianceActionItemRead {
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
            exceedance_kind: parse_exceedance_kind(
                item["exceedance_kind"].as_str().unwrap_or_default(),
            ),
        })
        .collect();
    let blueprint_timing_adjustment_proposals = value["blueprint_timing_adjustment_proposals"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|proposal| BlueprintTimingAdjustmentProposalRead {
            crop_id: proposal["crop_id"].as_i64().unwrap_or(0),
            crop_name: proposal["crop_name"].as_str().unwrap_or_default().to_string(),
            category: proposal["category"].as_str().unwrap_or_default().to_string(),
            average_delta_days: proposal["average_delta_days"].as_f64().unwrap_or(0.0),
            average_gdd_delta: proposal["average_gdd_delta"].as_f64(),
            recorded_item_count: proposal["recorded_item_count"].as_i64().unwrap_or(0),
        })
        .collect();

    Ok(PlanVsActualSummaryRead {
        plan_id: value["plan_id"].as_i64().unwrap_or(plan_id),
        unrecorded_count: value["unrecorded_count"].as_i64().unwrap_or(0),
        structured_unrecorded_count: value["structured_unrecorded_count"].as_i64().unwrap_or(0),
        categories,
        top_variance_items,
        stage_gdd_calibration_proposals,
        action_required_items,
        blueprint_timing_adjustment_proposals,
    })
}

fn parse_exceedance_kind(raw: &str) -> VarianceExceedanceKind {
    match raw {
        "days" => VarianceExceedanceKind::Days,
        "gdd" => VarianceExceedanceKind::Gdd,
        "both" => VarianceExceedanceKind::Both,
        _ => VarianceExceedanceKind::Days,
    }
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
                 );
                 CREATE TABLE plan_variance_learning_proposal_states (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   plan_id INTEGER NOT NULL,
                   proposal_key TEXT NOT NULL,
                   status TEXT NOT NULL,
                   created_at TEXT NOT NULL DEFAULT (datetime('now')),
                   updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                   UNIQUE(plan_id, proposal_key)
                 );
                 CREATE TABLE plan_variance_learning_orchestration_steps (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   plan_id INTEGER NOT NULL UNIQUE,
                   placement_complete INTEGER NOT NULL DEFAULT 0,
                   regenerate_complete INTEGER NOT NULL DEFAULT 0,
                   sync_verify_complete INTEGER NOT NULL DEFAULT 0,
                   return_to_learn INTEGER NOT NULL DEFAULT 0,
                   pipeline_active INTEGER NOT NULL DEFAULT 0,
                   current_phase TEXT NOT NULL DEFAULT 'idle',
                   last_error TEXT,
                   created_at TEXT NOT NULL DEFAULT (datetime('now')),
                   updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                 );
                 CREATE TABLE plan_variance_learning_handoff_states (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   plan_id INTEGER NOT NULL UNIQUE,
                   handoff_json TEXT NOT NULL DEFAULT '{}',
                   created_at TEXT NOT NULL DEFAULT (datetime('now')),
                   updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                 );",
            )
        })
        .expect("schema");
        pool
    }

    #[test]
    fn save_and_find_round_trip_preserves_learning_proposals() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);
        let summary = PlanVsActualSummaryRead {
            plan_id: 21,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            categories: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 3,
                crop_name: "Tomato".into(),
                stage_order: 2,
                stage_name: "Vegetative".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 4,
            }],
            action_required_items: vec![PlanVarianceActionItemRead {
                item_id: 9,
                field_cultivation_id: 5,
                category: "general".into(),
                name: "Weeding".into(),
                scheduled_date: Some("2026-06-01".into()),
                actual_date: Some("2026-06-10".into()),
                delta_days: Some(9),
                gdd_trigger: Some(100.0),
                gdd_at_actual: Some(120.0),
                gdd_delta: Some(20.0),
                exceedance_kind: VarianceExceedanceKind::Both,
            }],
            blueprint_timing_adjustment_proposals: vec![BlueprintTimingAdjustmentProposalRead {
                crop_id: 3,
                crop_name: "Tomato".into(),
                category: "general".into(),
                average_delta_days: 5.0,
                average_gdd_delta: Some(8.0),
                recorded_item_count: 3,
            }],
        };

        gateway.save(21, 10, &summary).expect("save");
        let found = gateway
            .find_by_plan_id(21)
            .expect("find")
            .expect("snapshot");
        let stored = found.summary.expect("summary");
        assert_eq!(1, stored.stage_gdd_calibration_proposals.len());
        assert_eq!(12.5, stored.stage_gdd_calibration_proposals[0].average_gdd_delta);
        assert_eq!(1, stored.action_required_items.len());
        assert_eq!(VarianceExceedanceKind::Both, stored.action_required_items[0].exceedance_kind);
        assert_eq!(1, stored.blueprint_timing_adjustment_proposals.len());
        assert_eq!(5.0, stored.blueprint_timing_adjustment_proposals[0].average_delta_days);
    }

    #[test]
    fn save_and_find_round_trip() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);
        let summary = PlanVsActualSummaryRead {
            plan_id: 20,
            unrecorded_count: 1,
            structured_unrecorded_count: 0,
            categories: vec![PlanVsActualCategorySummaryRead {
                category: "general".into(),
                average_delta_days: Some(3.0),
                item_count: 2,
                recorded_count: 1,
            }],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
        };

        gateway.save(20, 10, &summary).expect("save");
        let found = gateway
            .find_by_plan_id(20)
            .expect("find")
            .expect("snapshot");
        assert_eq!(20, found.plan_id);
        assert_eq!(Some(10), found.source_plan_id);
        assert_eq!(1, found.summary.as_ref().unwrap().unrecorded_count);
        assert_eq!(
            Some(3.0),
            found.summary.as_ref().unwrap().categories[0].average_delta_days
        );
    }

    #[test]
    fn upsert_and_find_proposal_application_progress() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);
        let mut updates = BTreeMap::new();
        updates.insert("stage_gdd:1:2".into(), "dismissed".into());

        gateway
            .upsert_proposal_application_progress(7, &updates)
            .expect("upsert");
        let found = gateway
            .find_proposal_application_progress_by_plan_id(7)
            .expect("find");
        assert_eq!(
            BTreeMap::from([("stage_gdd:1:2".into(), "dismissed".into())]),
            found
        );

        updates.insert("stage_gdd:1:2".into(), "confirmed".into());
        gateway
            .upsert_proposal_application_progress(7, &updates)
            .expect("upsert again");
        let updated = gateway
            .find_proposal_application_progress_by_plan_id(7)
            .expect("find updated");
        assert_eq!("confirmed", updated.get("stage_gdd:1:2").unwrap());
    }

    #[test]
    fn upsert_and_find_reorganize_orchestration_progress() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);

        let empty = gateway
            .find_reorganize_orchestration_progress_by_plan_id(9)
            .expect("find empty");
        assert_eq!(ReorganizeOrchestrationProgressRead::default(), empty);

        gateway
            .upsert_reorganize_orchestration_progress(
                9,
                &ReorganizeOrchestrationProgressPatch {
                    placement: Some(true),
                    regenerate: None,
                    sync_verify: None,
                    return_to_learn: Some(true),
                    pipeline_active: Some(true),
                    current_phase: Some("optimizing".into()),
                    last_error: Some(Some("weather fetch failed".into())),
                },
            )
            .expect("upsert");

        let found = gateway
            .find_reorganize_orchestration_progress_by_plan_id(9)
            .expect("find");
        assert!(found.placement);
        assert!(!found.regenerate);
        assert!(!found.sync_verify);
        assert!(found.return_to_learn);
        assert!(found.pipeline_active);
        assert_eq!("optimizing", found.current_phase);
        assert_eq!(
            Some("weather fetch failed".to_string()),
            found.last_error
        );

        gateway
            .upsert_reorganize_orchestration_progress(
                9,
                &ReorganizeOrchestrationProgressPatch {
                    regenerate: Some(true),
                    return_to_learn: Some(false),
                    placement: None,
                    sync_verify: None,
                    pipeline_active: None,
                    current_phase: Some("regenerate".into()),
                    last_error: Some(None),
                },
            )
            .expect("upsert partial");

        let updated = gateway
            .find_reorganize_orchestration_progress_by_plan_id(9)
            .expect("find updated");
        assert!(updated.placement);
        assert!(updated.regenerate);
        assert!(!updated.return_to_learn);
        assert!(updated.pipeline_active);
        assert_eq!("regenerate", updated.current_phase);
        assert_eq!(None, updated.last_error);
    }

    #[test]
    fn patch_and_find_learn_handoff() {
        let pool = test_pool();
        let gateway = PlanVarianceLearningSqliteGateway::new(pool);

        let empty = gateway
            .find_learn_handoff_by_plan_id(11)
            .expect("find empty handoff");
        assert!(empty.is_empty());

        let payload = json!({
            "kind": "stage_gdd",
            "cropId": 1,
            "cropName": "Tomato",
            "stageId": 2
        });
        gateway
            .patch_learn_handoff(
                11,
                &LearnHandoffStatePatch {
                    post_master_payload: Some(Some(payload.clone())),
                    ..Default::default()
                },
            )
            .expect("patch post_master");

        let found = gateway
            .find_learn_handoff_by_plan_id(11)
            .expect("find handoff");
        assert_eq!(Some(payload), found.post_master_payload);

        gateway
            .patch_learn_handoff(
                11,
                &LearnHandoffStatePatch {
                    post_master_payload: Some(None),
                    ..Default::default()
                },
            )
            .expect("clear post_master");

        let cleared = gateway
            .find_learn_handoff_by_plan_id(11)
            .expect("find cleared handoff");
        assert!(cleared.post_master_payload.is_none());
    }
}
