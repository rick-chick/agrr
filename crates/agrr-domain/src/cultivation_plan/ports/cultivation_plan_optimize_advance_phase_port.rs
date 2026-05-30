//! Phase advance during optimize (Rails `AdvanceCultivationPlanPhaseInteractor`).

use crate::cultivation_plan::dtos::CultivationPlanPhaseName;

/// Ruby: `advance_phase_interactor.call` from `CultivationPlanOptimizeInteractor`.
pub trait CultivationPlanOptimizeAdvancePhasePort: Send + Sync {
    fn advance(
        &self,
        plan_id: i64,
        channel_class: &str,
        phase_name: CultivationPlanPhaseName,
        failure_subphase: Option<&str>,
    );
}
