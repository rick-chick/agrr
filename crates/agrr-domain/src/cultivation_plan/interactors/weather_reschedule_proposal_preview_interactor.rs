//! Ruby: `Domain::CultivationPlan::Interactors::WeatherRescheduleProposalPreviewInteractor`

use crate::cultivation_plan::dtos::{
    CultivationPlanRestAuth, PlanAllocationAdjustFailure, PlanAllocationAdjustInput,
    PlanAllocationAdjustOutput, WeatherRescheduleProposalPreviewRead,
};
use crate::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, CultivationPlanGateway, CultivationPlanOptimizationEventsGateway,
    PlanAllocationAdjustDebugDumpGateway, PlanAllocationAdjustGateway,
    PlanAllocationAdjustReadGateway, WeatherRescheduleProposalReadGateway,
};
use crate::cultivation_plan::interactors::plan_allocation_adjust_interactor::PlanAllocationAdjustInteractor;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::mappers::weather_reschedule_proposal_mapper::WeatherRescheduleProposalMapper;
use crate::cultivation_plan::mappers::weather_reschedule_proposal_preview_mapper::WeatherRescheduleProposalPreviewMapper;
use crate::cultivation_plan::mappers::PlanAllocationAdjustAgrrPayloadMapper;
use crate::cultivation_plan::ports::{
    PlanAllocationAdjustInputPort, PlanAllocationAdjustOutputPort,
    WeatherRescheduleProposalPreviewOutputPort,
};
use crate::field_cultivation::ports::FieldCultivationSyncInputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

struct PreviewAdjustCapture {
    success: Option<PlanAllocationAdjustOutput>,
    failure: Option<PlanAllocationAdjustFailure>,
}

impl PlanAllocationAdjustOutputPort for PreviewAdjustCapture {
    fn on_success(&mut self, output: PlanAllocationAdjustOutput) {
        self.success = Some(output);
    }

    fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        self.failure = Some(failure);
    }
}

pub struct WeatherRescheduleProposalPreviewInteractor<'a, O, L, T, C, G, R, AR, A, E, D, WP, FCS, U, S> {
    output_port: &'a mut O,
    logger: &'a L,
    translator: &'a T,
    clock: &'a C,
    user_id: i64,
    plan_id: i64,
    proposal_id: String,
    cultivation_plan_gateway: &'a G,
    read_gateway: &'a R,
    adjust_read_gateway: &'a AR,
    adjust_gateway: &'a A,
    optimization_events_gateway: &'a E,
    debug_dump_gateway: &'a D,
    weather_prediction_gateway: &'a WP,
    field_cultivation_sync: &'a mut FCS,
    interaction_rule_random_hex: &'a str,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, O, L, T, C, G, R, AR, A, E, D, WP, FCS, U, S>
    WeatherRescheduleProposalPreviewInteractor<'a, O, L, T, C, G, R, AR, A, E, D, WP, FCS, U, S>
where
    O: WeatherRescheduleProposalPreviewOutputPort,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
    G: CultivationPlanGateway,
    R: WeatherRescheduleProposalReadGateway,
    AR: PlanAllocationAdjustReadGateway,
    A: PlanAllocationAdjustGateway,
    E: CultivationPlanOptimizationEventsGateway,
    D: PlanAllocationAdjustDebugDumpGateway,
    WP: AdjustWeatherPredictionGateway,
    FCS: FieldCultivationSyncInputPort + Send + Sync,
    U: UserLookupGateway,
    S: UserOrganizationScopeGateway,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut O,
        logger: &'a L,
        translator: &'a T,
        clock: &'a C,
        user_id: i64,
        plan_id: i64,
        proposal_id: String,
        cultivation_plan_gateway: &'a G,
        read_gateway: &'a R,
        adjust_read_gateway: &'a AR,
        adjust_gateway: &'a A,
        optimization_events_gateway: &'a E,
        debug_dump_gateway: &'a D,
        weather_prediction_gateway: &'a WP,
        field_cultivation_sync: &'a mut FCS,
        interaction_rule_random_hex: &'a str,
        user_lookup: &'a U,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            logger,
            translator,
            clock,
            user_id,
            plan_id,
            proposal_id,
            cultivation_plan_gateway,
            read_gateway,
            adjust_read_gateway,
            adjust_gateway,
            optimization_events_gateway,
            debug_dump_gateway,
            weather_prediction_gateway,
            field_cultivation_sync,
            interaction_rule_random_hex,
            user_lookup,
            scope_gateway,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let org_ids = member_organization_ids(self.scope_gateway, user.id)?;

        if !task_schedule_private_plan_access::access_allowed(
            self.cultivation_plan_gateway,
            self.plan_id,
            user.id,
            &org_ids,
        ) {
            return Err(Box::new(RecordNotFoundError));
        }

        let context = self.read_gateway.find_context_by_plan_id(self.plan_id)?;
        let proposals = WeatherRescheduleProposalMapper::proposals_from_context(&context);
        let Some(proposal) = proposals.into_iter().find(|row| row.id == self.proposal_id) else {
            return Err(Box::new(RecordNotFoundError));
        };

        let snapshot = self
            .adjust_read_gateway
            .find_adjust_read_snapshot_by_plan_id(self.plan_id)?;
        let current_allocation = PlanAllocationAdjustAgrrPayloadMapper::to_current_allocation(
            &snapshot,
            &[],
            self.logger,
        );
        let before =
            WeatherRescheduleProposalPreviewMapper::before_from_current_allocation(&current_allocation);

        let mut capture = PreviewAdjustCapture {
            success: None,
            failure: None,
        };
        let mut adjust_interactor = PlanAllocationAdjustInteractor::new(
            &mut capture,
            self.logger,
            self.translator,
            self.clock,
            self.cultivation_plan_gateway,
            self.adjust_read_gateway,
            self.adjust_gateway,
            self.optimization_events_gateway,
            self.debug_dump_gateway,
            self.weather_prediction_gateway,
            self.field_cultivation_sync,
            self.interaction_rule_random_hex,
        );
        adjust_interactor.call(PlanAllocationAdjustInput {
            plan_id: self.plan_id,
            moves: proposal.moves.clone(),
            auth: Some(CultivationPlanRestAuth::private(self.user_id)),
            dry_run: true,
        })?;

        if let Some(failure) = capture.failure {
            self.output_port.on_failure(failure);
            return Ok(());
        }

        let Some(success) = capture.success else {
            return Err("preview adjust produced no response".into());
        };
        let Some(adjust_payload) = success.adjust_result else {
            return Err("preview adjust missing adjust_result".into());
        };

        let preview = WeatherRescheduleProposalPreviewRead {
            proposal_id: proposal.id.clone(),
            moves: proposal.moves.clone(),
            proposal,
            before,
            after: WeatherRescheduleProposalPreviewMapper::after_from_adjust_result(&adjust_payload),
        };
        self.output_port.on_success(preview);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_weather_reschedule_proposal_preview_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_weather_reschedule_proposal_preview_interactor_test.rs"
    ));
}
