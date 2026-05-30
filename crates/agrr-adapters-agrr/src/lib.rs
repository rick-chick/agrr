//! agrr Python daemon / CLI client (Unix socket).
//!
//! Ruby: `Adapters::Agrr::Gateways::DaemonClient`

mod crop_ai_query_daemon_gateway;
mod daemon_ai_query;
mod daemon_client;
mod daemon_response;
mod daemon_temp_file;
mod fertilize_ai_query_daemon_gateway;
mod pest_ai_query_daemon_gateway;
mod entry_schedule_optimization_gateway;
mod field_cultivation_climate_gateway;
mod plan_allocation_adjust_gateway;
mod plan_allocation_allocate_gateway;
mod plan_allocation_candidates_gateway;
mod prediction_daemon_gateway;
mod weather_daemon_gateway;

pub use crop_ai_query_daemon_gateway::CropAiQueryDaemonGateway;
pub use daemon_client::{AgrrDaemonClient, AgrrDaemonError};
pub use fertilize_ai_query_daemon_gateway::FertilizeAiQueryDaemonGateway;
pub use pest_ai_query_daemon_gateway::PestAiQueryDaemonGateway;
pub use daemon_response::parse_daemon_json_payload;
pub use daemon_temp_file::{path_string, read_json_file, write_temp_json};
pub use entry_schedule_optimization_gateway::EntryScheduleOptimizationAgrrDaemonGateway;
pub use field_cultivation_climate_gateway::FieldCultivationClimateAgrrGateway;
pub use plan_allocation_adjust_gateway::PlanAllocationAdjustAgrrDaemonGateway;
pub use plan_allocation_allocate_gateway::PlanAllocationAllocateAgrrDaemonGateway;
pub use plan_allocation_candidates_gateway::PlanAllocationCandidatesAgrrDaemonGateway;
pub use prediction_daemon_gateway::PredictionDaemonGateway;
pub use weather_daemon_gateway::WeatherDaemonGateway;
