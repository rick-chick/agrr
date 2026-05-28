use serde_json::Value;

/// Ruby: `Domain::Shared::Ports::CultivationPlanPhaseBroadcastPort`
pub trait CultivationPlanPhaseBroadcastPort: Send + Sync {
    fn broadcast_phase_update(
        &self,
        plan_id: i64,
        channel_class: &str,
        payload: &Value,
    );
}
