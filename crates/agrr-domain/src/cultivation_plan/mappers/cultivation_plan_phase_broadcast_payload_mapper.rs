//! Ruby: `Domain::CultivationPlan::Mappers::CultivationPlanPhaseBroadcastPayloadMapper`

use serde_json::{json, Value};

use crate::cultivation_plan::entities::CultivationPlanEntity;

pub fn to_port_payload(
    plan: &CultivationPlanEntity,
    progress: i32,
    phase_message: Option<&str>,
) -> Value {
    let phase = plan.optimization_phase.as_deref().unwrap_or("");
    let message_key = format!("models.cultivation_plan.phases.{phase}");
    let status = plan.status.as_deref().unwrap_or("");
    json!({
        "status": status,
        "progress": progress,
        "phase": phase,
        "phase_message": phase_message,
        "message": phase_message,
        "message_key": message_key,
    })
}
