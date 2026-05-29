//! Cultivation plan narrow read gateways (P6-3).
//!
//! Ruby §P4 split gateways — implement trait-by-trait per cutover PR.

mod cultivation_plan_gateway;
mod plan_allocation_adjust_read_gateway;
mod field_mutation_gateway;
mod plan_crop_gateway;
mod private_read_gateway;
mod private_snapshot_read_gateway;
mod crop_rows_available_private_gateway;
mod rest_plan_read;
mod rest_plan_read_domain_gateway;
mod task_schedule_timeline_read;
mod public_plan_save_read_gateway;
mod plan_save_persistence;

pub use cultivation_plan_gateway::CultivationPlanSqliteGateway;
pub use plan_save_persistence::PublicPlanSavePersistenceSqliteAdapter;
pub use public_plan_save_read_gateway::PublicPlanSaveReadSqliteGateway;
pub use plan_allocation_adjust_read_gateway::PlanAllocationAdjustReadSqliteGateway;
pub use field_mutation_gateway::CultivationPlanFieldMutationSqliteGateway;
pub use plan_crop_gateway::CultivationPlanPlanCropSqliteGateway;
pub use private_read_gateway::CultivationPlanPrivateReadSqliteGateway;
pub use private_snapshot_read_gateway::CultivationPlanPrivateSnapshotReadSqliteGateway;
pub use crop_rows_available_private_gateway::CropRowsAvailablePrivateSqliteGateway;
pub use rest_plan_read::CultivationPlanRestPlanReadSqliteGateway;
pub use rest_plan_read_domain_gateway::CultivationPlanRestPlanReadDomainSqliteGateway;
