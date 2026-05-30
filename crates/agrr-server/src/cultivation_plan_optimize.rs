//! Rails `OptimizationJob` wiring for `CultivationPlanOptimizeInteractor`.
//!
//! Phase split (Rails parity):
//! - Interactor: `StartOptimizing`, `PhaseOptimizing` (via `CultivationPlanOptimizeAdvancePhasePort`)
//! - `run_optimization_step` (job): `PhaseOptimizationCompleted` on success; chain on failure: `PhaseFailed` + `optimizing`

use crate::adapters::{NoopLogger, SystemClock};
use crate::optimization_job_chain::advance_phase;
use crate::state::AppState;
use agrr_adapters_agrr::PlanAllocationAllocateAgrrDaemonGateway;
use agrr_adapters_sqlite::{
    CultivationPlanOptimizationSqliteGateway, InteractionRulePlanReadSqliteGateway,
    OptimizationPlanReadSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;
use agrr_domain::cultivation_plan::interactors::CultivationPlanOptimizeInteractor;
use agrr_domain::cultivation_plan::ports::CultivationPlanOptimizeAdvancePhasePort;
use crate::adjust_weather_prediction::SqliteAdjustWeatherPredictionGateway;

struct ChainOptimizeAdvance<'a> {
    state: &'a AppState,
}

impl CultivationPlanOptimizeAdvancePhasePort for ChainOptimizeAdvance<'_> {
    fn advance(
        &self,
        plan_id: i64,
        channel_class: &str,
        phase_name: CultivationPlanPhaseName,
        failure_subphase: Option<&str>,
    ) {
        advance_phase(
            self.state,
            plan_id,
            channel_class,
            phase_name,
            failure_subphase,
        );
    }
}

/// Runs optimize interactor; `PhaseOptimizationCompleted` is advanced by the caller (job parity).
pub fn run_cultivation_plan_optimize_interactor(
    state: &AppState,
    plan_id: i64,
    channel: &str,
) -> Result<(), String> {
    let pool = state.sqlite.clone();
    let read = OptimizationPlanReadSqliteGateway::new(pool.clone());
    let optimization = CultivationPlanOptimizationSqliteGateway::new(pool.clone());
    let rules = InteractionRulePlanReadSqliteGateway::new(pool.clone());
    let allocate = PlanAllocationAllocateAgrrDaemonGateway::from_env();
    let weather = SqliteAdjustWeatherPredictionGateway::new(pool);
    let advance = ChainOptimizeAdvance { state };
    let logger = NoopLogger;
    let clock = SystemClock;

    let interactor = CultivationPlanOptimizeInteractor::new(
        plan_id,
        channel,
        &allocate,
        &rules,
        &optimization,
        &read,
        &advance,
        &weather,
        &logger,
        &clock,
    );

    interactor
        .call()
        .map(|_| ())
        .map_err(|e| e.to_string())
}
