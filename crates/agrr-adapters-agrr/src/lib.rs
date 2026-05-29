//! agrr Python daemon / CLI client (Unix socket).
//!
//! Ruby: `Adapters::Agrr::Gateways::DaemonClient`

mod daemon_client;
mod entry_schedule_optimization_gateway;
mod field_cultivation_climate_gateway;
mod plan_allocation_adjust_gateway;
mod plan_allocation_allocate_gateway;
mod plan_allocation_candidates_gateway;
mod prediction_daemon_gateway;
mod weather_daemon_gateway;

pub use daemon_client::{AgrrDaemonClient, AgrrDaemonError};
pub use entry_schedule_optimization_gateway::EntryScheduleOptimizationAgrrDaemonGateway;
pub use field_cultivation_climate_gateway::FieldCultivationClimateAgrrGateway;
pub use plan_allocation_adjust_gateway::PlanAllocationAdjustAgrrDaemonGateway;
pub use plan_allocation_allocate_gateway::PlanAllocationAllocateAgrrDaemonGateway;
pub use plan_allocation_candidates_gateway::PlanAllocationCandidatesAgrrDaemonGateway;
pub use prediction_daemon_gateway::PredictionDaemonGateway;
pub use weather_daemon_gateway::WeatherDaemonGateway;
