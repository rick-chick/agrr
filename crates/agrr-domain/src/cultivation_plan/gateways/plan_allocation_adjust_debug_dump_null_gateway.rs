//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway`

use super::PlanAllocationAdjustDebugDumpGateway;
use serde_json::Value;

/// No-op debug dump (production).
pub struct PlanAllocationAdjustDebugDumpNullGateway;

impl PlanAllocationAdjustDebugDumpGateway for PlanAllocationAdjustDebugDumpNullGateway {
    fn dump_payload(
        &self,
        _current_allocation: &Value,
        _moves: &[Value],
        _fields: &[Value],
        _crops: &[Value],
    ) {
    }
}
