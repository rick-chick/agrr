//! Wire adjust debug dump gateway (Rails `CompositionRoot#plan_allocation_adjust_debug_dump_gateway`).

use std::path::PathBuf;

use agrr_adapters_sqlite::PlanAllocationAdjustDebugDumpFileGateway;
use agrr_domain::cultivation_plan::gateways::{
    PlanAllocationAdjustDebugDumpGateway, PlanAllocationAdjustDebugDumpNullGateway,
};
use agrr_domain::shared::ports::{ClockPort, LoggerPort};
use serde_json::Value;

use crate::runtime_env;

pub fn project_root() -> PathBuf {
    std::env::var("AGRR_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
        })
}

/// Production → null; otherwise file gateway under `tmp/debug`.
pub enum PlanAllocationAdjustDebugDump<'a> {
    Null(PlanAllocationAdjustDebugDumpNullGateway),
    File(PlanAllocationAdjustDebugDumpFileGateway<'a>),
}

impl PlanAllocationAdjustDebugDumpGateway for PlanAllocationAdjustDebugDump<'_> {
    fn dump_payload(
        &self,
        current_allocation: &Value,
        moves: &[Value],
        fields: &[Value],
        crops: &[Value],
    ) {
        match self {
            Self::Null(g) => g.dump_payload(current_allocation, moves, fields, crops),
            Self::File(g) => g.dump_payload(current_allocation, moves, fields, crops),
        }
    }
}

pub fn plan_allocation_adjust_debug_dump<'a>(
    clock: &'a dyn ClockPort,
    logger: &'a dyn LoggerPort,
) -> PlanAllocationAdjustDebugDump<'a> {
    if runtime_env::is_production() {
        PlanAllocationAdjustDebugDump::Null(PlanAllocationAdjustDebugDumpNullGateway)
    } else {
        PlanAllocationAdjustDebugDump::File(PlanAllocationAdjustDebugDumpFileGateway::new(
            project_root(),
            clock,
            logger,
        ))
    }
}
