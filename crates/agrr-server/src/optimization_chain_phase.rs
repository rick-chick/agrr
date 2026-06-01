//! Cultivation-plan optimization phase updates and Cable broadcasts (edge adapter).

use crate::adapters::PassthroughTranslator;
use crate::cable::CableHub;
use crate::state::AppState;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::dtos::{
    AdvanceCultivationPlanPhaseInput, CultivationPlanPhaseName,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::interactors::AdvanceCultivationPlanPhaseInteractor;
use agrr_domain::shared::ports::CultivationPlanPhaseBroadcastPort;
use rusqlite::params;
use serde_json::{json, Value};
use std::sync::Arc;

struct CablePhaseBroadcast {
    hub: Arc<CableHub>,
}

impl CultivationPlanPhaseBroadcastPort for CablePhaseBroadcast {
    fn broadcast_phase_update(&self, plan_id: i64, _channel_class: &str, payload: &Value) {
        self.hub.broadcast_plan_message(plan_id, payload.clone());
    }
}

pub(crate) fn plan_still_optimizing(pool: &agrr_adapters_sqlite::SqlitePool, plan_id: i64) -> bool {
    pool.with_read(|conn| {
        let status: String = conn.query_row(
            "SELECT status FROM cultivation_plans WHERE id = ?1",
            params![plan_id],
            |row| row.get(0),
        )?;
        Ok(status == "optimizing")
    })
    .unwrap_or(false)
}

pub(crate) fn advance_phase(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    phase_name: CultivationPlanPhaseName,
    failure_subphase: Option<&str>,
) -> Result<(), String> {
    let plan_gateway = CultivationPlanSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let broadcast = CablePhaseBroadcast {
        hub: state.cable_hub.clone(),
    };
    let interactor =
        AdvanceCultivationPlanPhaseInteractor::new(&plan_gateway, &translator, &broadcast);
    interactor
        .call(AdvanceCultivationPlanPhaseInput {
            plan_id,
            phase_name,
            channel_class: Some(channel.to_string()),
            failure_subphase: failure_subphase.map(str::to_string),
        })
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub(crate) fn broadcast_completed(
    hub: &CableHub,
    plan_id: i64,
    pool: &agrr_adapters_sqlite::SqlitePool,
) {
    let gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let Ok(plan) = gateway.find_by_id(plan_id) else {
        return;
    };
    let Ok(field_cultivations) = gateway.list_by_plan_id(plan_id) else {
        return;
    };
    let statuses: Vec<String> = field_cultivations
        .iter()
        .filter_map(|fc| fc.status.clone())
        .collect();
    let plan_status = plan.status.as_deref().unwrap_or("");
    let all_fc_completed = !field_cultivations.is_empty()
        && statuses.iter().all(|s| s == "completed");
    if plan_status != "completed" || !all_fc_completed {
        eprintln!(
            "optimization chain: skip broadcast_completed plan_id={plan_id} status={plan_status} field_cultivations={}",
            field_cultivations.len()
        );
        return;
    }
    hub.broadcast_plan_message(
        plan_id,
        json!({
            "status": "completed",
            "progress": 100,
            "phase": "completed",
            "phase_message": "Completed",
            "message_key": "models.cultivation_plan.phases.completed"
        }),
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::{test_app_state, test_pool_with_plan};

    #[test]
    fn advance_phase_returns_err_when_plan_missing() {
        let state = test_app_state(test_pool_with_plan(1).pool);
        let err = advance_phase(
            &state,
            999,
            "PublicPlanChannel",
            CultivationPlanPhaseName::StartOptimizing,
            None,
        )
        .expect_err("missing plan should fail");
        assert!(
            !err.is_empty(),
            "error message should describe failure: {err}"
        );
    }
}
