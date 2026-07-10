//! Ruby: `Domain::CultivationPlan::Interactors::AdvanceCultivationPlanPhaseInteractor`

use crate::cultivation_plan::calculators::cultivation_plan_optimization_progress_calculator;
use crate::cultivation_plan::dtos::{AdvanceCultivationPlanPhaseInput, CultivationPlanPhaseName};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::mappers::to_port_payload;
use crate::cultivation_plan::optimization_completion;
use crate::cultivation_plan::policies::cultivation_plan_phase_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::ports::CultivationPlanPhaseBroadcastPort;

pub struct AdvanceCultivationPlanPhaseInteractor<'a, G, T, B> {
    cultivation_plan_gateway: &'a G,
    translator: &'a T,
    phase_broadcast_port: &'a B,
}

impl<'a, G, T, B> AdvanceCultivationPlanPhaseInteractor<'a, G, T, B>
where
    G: CultivationPlanGateway,
    T: TranslatorPort,
    B: CultivationPlanPhaseBroadcastPort,
{
    pub fn new(
        cultivation_plan_gateway: &'a G,
        translator: &'a T,
        phase_broadcast_port: &'a B,
    ) -> Self {
        Self {
            cultivation_plan_gateway,
            translator,
            phase_broadcast_port,
        }
    }

    pub fn call(
        &self,
        input: AdvanceCultivationPlanPhaseInput,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        let built = cultivation_plan_phase_policy::build(
            input.phase_name,
            input.failure_subphase.as_deref(),
        );
        let mut attrs = built.attrs.clone();
        if let Some(message_key) = built.message_key.as_deref() {
            let message = if input.phase_name == CultivationPlanPhaseName::PhaseFailed {
                message_key.to_string()
            } else {
                self.translator
                    .t(message_key, &TranslateOptions::default())
            };
            attrs.insert("optimization_phase_message".into(), message);
        }

        let mut plan = self
            .cultivation_plan_gateway
            .update(input.plan_id, attrs)?;

        if built.broadcast {
            if let Some(channel_class) = input.channel_class.as_deref() {
                let field_cultivations = self
                    .cultivation_plan_gateway
                    .list_by_plan_id(input.plan_id)?;
                let progress = cultivation_plan_optimization_progress_calculator::progress_percent(
                    &field_cultivations,
                );
                let phase_message = plan.optimization_phase_message.as_deref();
                let payload = to_port_payload(
                    &plan,
                    progress,
                    phase_message,
                );
                self.phase_broadcast_port.broadcast_phase_update(
                    input.plan_id,
                    channel_class,
                    &payload,
                );
            }
        }

        plan = optimization_completion::apply(self.cultivation_plan_gateway, input.plan_id)?;
        Ok(plan)
    }
}

#[cfg(test)]
mod interactors_advance_cultivation_plan_phase_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_advance_cultivation_plan_phase_interactor_test.rs"));
}
