//! Rails `OptimizationJob` wiring for `CultivationPlanOptimizeInteractor`.
//!
//! Phase split:
//! - Interactor: `PhaseOptimizing` (`StartOptimizing` is broadcast synchronously when the job chain is enqueued)
//! - `run_optimization_step`: no `PhaseOptimizationCompleted` (Rails-only; no task schedule job in Rust chain)
//! - Chain on failure: `PhaseFailed` + `optimizing`; success continues to `plan_finalize` → `PhaseCompleted`
//!
//! Weather (Rails `CultivationPlanOptimizeInteractor#call` 同様): `get_existing_prediction` のみ。
//! `predict_for_cultivation_plan` は `run_weather_prediction_step`（Rails `WeatherPredictionJob`）で先行実行。

use crate::adapters::{NoopLogger, SystemClock};
use crate::optimization_chain_phase::advance_phase;
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
        let _ = advance_phase(
            self.state,
            plan_id,
            channel_class,
            phase_name,
            failure_subphase,
        );
    }
}

/// Runs optimize interactor; phase completion is handled by `run_plan_finalize_step`.
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
