//! SQLite gateways for `agrr_domain::work_record`.

mod task_schedule_item_lookup_gateway;
mod work_record_gateway;

#[cfg(test)]
mod work_record_integration_fixture;
#[cfg(test)]
mod work_record_gateway_integration_test;

pub use task_schedule_item_lookup_gateway::TaskScheduleItemLookupSqliteGateway;
pub use work_record_gateway::WorkRecordSqliteGateway;
