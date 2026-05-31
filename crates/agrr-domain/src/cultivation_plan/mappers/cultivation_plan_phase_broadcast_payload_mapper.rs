//! Ruby: `Domain::CultivationPlan::Mappers::CultivationPlanPhaseBroadcastPayloadMapper`

use serde_json::{json, Value};

use crate::cultivation_plan::entities::CultivationPlanEntity;

/// Rails job chain only. agrr-server never sets these; remap stale DB rows for Cable/UI.
fn cable_phase(optimization_phase: &str) -> &str {
    match optimization_phase {
        "optimization_completed" | "task_schedule_generating" => "optimizing",
        other => other,
    }
}

fn cable_message_key(stored_phase: &str, phase: &str, phase_message: Option<&str>) -> String {
    if stored_phase == "failed" {
        return phase_message
            .filter(|m| m.starts_with("models.cultivation_plan.phase_failed."))
            .map(str::to_string)
            .unwrap_or_else(|| "models.cultivation_plan.phase_failed.default".into());
    }
    format!("models.cultivation_plan.phases.{phase}")
}

pub fn to_port_payload(
    plan: &CultivationPlanEntity,
    progress: i32,
    phase_message: Option<&str>,
) -> Value {
    let stored_phase = plan.optimization_phase.as_deref().unwrap_or("");
    let phase = cable_phase(stored_phase);
    let message_key = cable_message_key(stored_phase, phase, phase_message);
    let status = plan.status.as_deref().unwrap_or("");
    let phase_message = if stored_phase == phase {
        phase_message
    } else {
        None
    };
    json!({
        "status": status,
        "progress": progress,
        "phase": phase,
        "phase_message": phase_message,
        "message": phase_message,
        "message_key": message_key,
    })
}

#[cfg(test)]
mod mappers_cultivation_plan_phase_broadcast_payload_mapper_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/mappers_cultivation_plan_phase_broadcast_payload_mapper_test.rs"
    ));
}
