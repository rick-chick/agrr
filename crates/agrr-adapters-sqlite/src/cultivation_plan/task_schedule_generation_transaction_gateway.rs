//! Transaction boundary for task schedule generation (pool mutex serializes writes).

use agrr_domain::agricultural_task::gateways::CultivationPlanGateway;

pub struct TaskScheduleGenerationTransactionSqliteGateway;

impl TaskScheduleGenerationTransactionSqliteGateway {
    pub fn new() -> Self {
        Self
    }
}

impl CultivationPlanGateway for TaskScheduleGenerationTransactionSqliteGateway {
    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T,
    {
        // Nested `with_write` from gateway methods would deadlock on the pool mutex;
        // run the block without an explicit SQL transaction until a connection-scoped API exists.
        block()
    }
}
