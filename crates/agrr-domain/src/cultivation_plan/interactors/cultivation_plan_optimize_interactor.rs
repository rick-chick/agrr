//! Ruby: `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor`

use std::fmt;

use crate::cultivation_plan::errors::{
    AllocationExecutionError, AllocationNoCandidatesError, CultivationPlanCropMissingError,
};
use crate::cultivation_plan::gateways::{
    CultivationPlanPrivateSnapshotReadGateway, PlanAllocationAllocateGateway,
};
use crate::cultivation_plan::policies::cultivation_plan_optimization_complete_policy;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::LoggerPort;

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherDataNotFoundError {
    pub message: String,
}

impl fmt::Display for WeatherDataNotFoundError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for WeatherDataNotFoundError {}

pub struct CultivationPlanOptimizeInteractor<'a, A, L, P> {
    plan_id: i64,
    allocate_gateway: &'a A,
    private_read_gateway: &'a P,
    logger: &'a L,
}

impl<'a, A, L, P> CultivationPlanOptimizeInteractor<'a, A, L, P>
where
    A: PlanAllocationAllocateGateway,
    P: CultivationPlanPrivateSnapshotReadGateway,
    L: LoggerPort,
{
    pub fn new(
        plan_id: i64,
        allocate_gateway: &'a A,
        private_read_gateway: &'a P,
        logger: &'a L,
    ) -> Self {
        Self {
            plan_id,
            allocate_gateway,
            private_read_gateway,
            logger,
        }
    }

    /// Core optimize path; weather/phase wiring stays at the Rails edge for now.
    pub fn call(
        &self,
        weather_data: &serde_json::Value,
        fields: &[serde_json::Value],
        crops: &[serde_json::Value],
        planning_start: time::Date,
        planning_end: time::Date,
        interaction_rules: Option<&serde_json::Value>,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let _snapshot = self
            .private_read_gateway
            .find_optimization_snapshot_by_plan_id(self.plan_id)?;

        if !_snapshot.weather_location_present {
            let message =
                "農場にWeatherLocationが設定されていません。気象データを取得してください。".to_string();
            self.logger.error(&format!("❌ [Optimizer] {message}"));
            return Err(Box::new(WeatherDataNotFoundError { message }));
        }

        self.logger.info(&format!(
            "🚀 [AGRR] Starting single allocation for {} fields and {} crops",
            fields.len(),
            crops.len()
        ));

        let allocation_result = self
            .allocate_gateway
            .allocate(
                fields,
                crops,
                weather_data,
                planning_start,
                planning_end,
                interaction_rules,
                "maximize_profit",
                None,
                false,
            )
            ?;

        if !cultivation_plan_optimization_complete_policy::allocation_has_field_schedules(
            &allocation_result,
        ) {
            return Err(Box::new(AllocationNoCandidatesError::new(
                "no field schedules in allocation result",
            )));
        }

        self.logger
            .info(&format!("✅ CultivationPlan #{} optimization completed", self.plan_id));
        Ok(true)
    }

    pub fn map_allocate_error(
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Box<dyn std::error::Error + Send + Sync> {
        if err.downcast_ref::<AllocationNoCandidatesError>().is_some()
            || err.downcast_ref::<AllocationExecutionError>().is_some()
            || err.downcast_ref::<WeatherDataNotFoundError>().is_some()
            || err.downcast_ref::<CultivationPlanCropMissingError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            return err;
        }
        err
    }
}
