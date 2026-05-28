//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpGateway`

use serde_json::Value;

pub trait PlanAllocationAdjustDebugDumpGateway: Send + Sync {
    fn dump_payload(
        &self,
        current_allocation: &Value,
        moves: &[Value],
        fields: &[Value],
        crops: &[Value],
    );
}
