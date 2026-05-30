//! Ruby: `Adapters::CultivationPlan::Gateways::PublicPlanSavePersistenceActiveRecordAdapter`

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{PublicPlanSaveFromSessionOutput, PublicPlanSaveWorkspace};
use agrr_domain::cultivation_plan::gateways::PublicPlanSaveTxnGateway;
use agrr_domain::cultivation_plan::ports::PublicPlanSavePersistencePort;

use super::cultivation_plan_gateway::CultivationPlanSqliteGateway;
use super::plan_save_session::{session_output_from_result, PlanSaveSession};
use super::plan_save_support::{PlanSaveClock, PlanSaveNoopLogger, PlanSavePassthroughTranslator};

pub struct PublicPlanSavePersistenceSqliteAdapter {
    pool: SqlitePool,
}

impl PublicPlanSavePersistenceSqliteAdapter {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl PublicPlanSavePersistencePort for PublicPlanSavePersistenceSqliteAdapter {
    fn execute_save(
        &self,
        workspace: &PublicPlanSaveWorkspace,
    ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>> {
        let logger = PlanSaveNoopLogger;
        let translator = PlanSavePassthroughTranslator;
        let clock = PlanSaveClock;
        let session = PlanSaveSession::new(
            self.pool.clone(),
            workspace,
            &logger,
            &translator,
            &clock,
        );
        let result = session.call()?;
        Ok(session_output_from_result(result))
    }
}

impl PublicPlanSaveTxnGateway for CultivationPlanSqliteGateway {
    fn within_transaction<F, T>(
        &self,
        block: F,
    ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
    {
        block()
    }
}
