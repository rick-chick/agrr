//! Ruby: `Domain::CultivationPlan::Interactors::PlanAllocationAdjustInteractor`

use crate::cultivation_plan::dtos::{
    PlanAllocationAdjustFailure, PlanAllocationAdjustInput, PlanAllocationAdjustOutput,
    PlanAllocationAdjustReadSnapshot,
};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, PlanAllocationAdjustDebugDumpGateway, PlanAllocationAdjustGateway,
    PlanAllocationAdjustReadGateway, CultivationPlanOptimizationEventsGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::mappers::{CropsConfigLogger, PlanAllocationAdjustAgrrPayloadMapper};
use crate::cultivation_plan::ports::{PlanAllocationAdjustInputPort, PlanAllocationAdjustOutputPort};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use serde_json::json;

pub struct PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG> {
    output_port: &'a mut O,
    logger: &'a L,
    translator: &'a T,
    clock: &'a C,
    plan_gateway: &'a PG,
    read_gateway: &'a R,
    adjust_gateway: &'a A,
    optimization_events_gateway: &'a E,
    debug_dump_gateway: &'a D,
    interaction_rule_random_hex: &'a str,
    adjust_read_snapshot: Option<PlanAllocationAdjustReadSnapshot>,
}

impl<'a, O, L, T, C, R, A, E, D, PG> PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG>
where
    O: PlanAllocationAdjustOutputPort,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
    R: PlanAllocationAdjustReadGateway,
    A: PlanAllocationAdjustGateway,
    E: CultivationPlanOptimizationEventsGateway,
    D: PlanAllocationAdjustDebugDumpGateway,
    PG: CultivationPlanGateway,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut O,
        logger: &'a L,
        translator: &'a T,
        clock: &'a C,
        plan_gateway: &'a PG,
        read_gateway: &'a R,
        adjust_gateway: &'a A,
        optimization_events_gateway: &'a E,
        debug_dump_gateway: &'a D,
        interaction_rule_random_hex: &'a str,
    ) -> Self {
        Self {
            output_port,
            logger,
            translator,
            clock,
            plan_gateway,
            read_gateway,
            adjust_gateway,
            optimization_events_gateway,
            debug_dump_gateway,
            interaction_rule_random_hex,
            adjust_read_snapshot: None,
        }
    }

    fn emit_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        self.output_port.on_failure(failure);
    }

    fn load_adjust_read_context(
        &mut self,
        plan_id: i64,
        auth: Option<&crate::cultivation_plan::dtos::CultivationPlanRestAuth>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(auth) = auth {
            let plan = self.plan_gateway.find_by_id(plan_id)?;
            if rest_plan_access::access_denied(&plan, auth) {
                return Err(Box::new(RecordNotFoundError));
            }
        }

        self.adjust_read_snapshot = Some(
            self.read_gateway
                .find_adjust_read_snapshot_by_plan_id(plan_id)?,
        );
        Ok(())
    }

    fn validate_plan_crop_growth_stages(&mut self) -> bool {
        let snapshot = self
            .adjust_read_snapshot
            .as_ref()
            .expect("snapshot loaded");
        for entry in &snapshot.plan_crop_snapshots {
            if entry.has_growth_stages {
                continue;
            }
            let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
            opts.insert("crop_name".into(), entry.crop_name.clone());
            let message = self
                .translator
                .translate("api.errors.cultivation_plan.crop_missing_growth_stages", &opts);
            self.emit_failure(PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES.into(),
                message,
            });
            return false;
        }
        true
    }

    fn pass_rest_adjust_preflight(&mut self, input: &PlanAllocationAdjustInput) -> bool {
        match self.load_adjust_read_context(input.plan_id, input.auth.as_ref()) {
            Ok(()) => {}
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_NOT_FOUND.into(),
                    message: self.translator.translate(
                        "api.errors.common.not_found",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                });
                return false;
            }
            Err(err) => {
                self.logger.error(&format!("❌ [Adjust read] {err}"));
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_UNEXPECTED.into(),
                    message: err.to_string(),
                });
                return false;
            }
        }

        self.validate_plan_crop_growth_stages()
    }
}

impl<'a, O, L, T, C, R, A, E, D, PG> PlanAllocationAdjustInputPort
    for PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG>
where
    O: PlanAllocationAdjustOutputPort,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
    R: PlanAllocationAdjustReadGateway,
    A: PlanAllocationAdjustGateway,
    E: CultivationPlanOptimizationEventsGateway,
    D: PlanAllocationAdjustDebugDumpGateway,
    PG: CultivationPlanGateway,
{
    fn call(
        &mut self,
        input: PlanAllocationAdjustInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if input.rest_adjust() && !self.pass_rest_adjust_preflight(&input) {
            return Ok(());
        }

        let perf_start = self.clock.now();
        self.logger
            .info(&format!("⏱️ [PERF] plan_allocation_adjust() 開始: {perf_start}"));

        if input.moves.is_empty() {
            self.logger
                .info("ℹ️ [Adjust] 移動指示が空のため調整をスキップします");
            self.output_port.on_success(PlanAllocationAdjustOutput {
                message: "調整不要（移動指示なし）".into(),
                skipped: true,
                payload: None,
                adjust_result: None,
            });
            return Ok(());
        }

        if self.adjust_read_snapshot.is_none() {
            self.load_adjust_read_context(input.plan_id, None)?;
        }

        let snapshot = self
            .adjust_read_snapshot
            .as_ref()
            .expect("snapshot loaded after load");

        let current_allocation =
            PlanAllocationAdjustAgrrPayloadMapper::to_current_allocation(snapshot, &[], self.logger);
        let fields = PlanAllocationAdjustAgrrPayloadMapper::to_fields_config(snapshot);
        let crops_logger = CropsConfigLogger(self.logger);
        let crops =
            PlanAllocationAdjustAgrrPayloadMapper::to_crops_config(snapshot, Some(&crops_logger));
        let interaction_rules = PlanAllocationAdjustAgrrPayloadMapper::to_interaction_rules(
            snapshot,
            self.interaction_rule_random_hex,
        );

        self.debug_dump_gateway.dump_payload(
            &current_allocation,
            &input.moves,
            &fields,
            &crops,
        );

        let interaction_rules_value = if interaction_rules.is_empty() {
            None
        } else {
            Some(json!({ "rules": interaction_rules }))
        };

        if snapshot.farm_without_weather_location {
            self.emit_failure(PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_NO_WEATHER_LOCATION.into(),
                message: self.translator.translate(
                    "api.errors.no_weather_data",
                    &crate::shared::ports::translator_port::TranslateOptions::new(),
                ),
            });
            return Ok(());
        }

        let cultivation_periods: Vec<crate::cultivation_plan::calculators::effective_planning_period_calculator::CultivationPeriodDate> = snapshot
            .cultivation_planning_periods
            .iter()
            .map(|p| crate::cultivation_plan::calculators::effective_planning_period_calculator::CultivationPeriodDate {
                start_date: p.start_date,
                completion_date: p.completion_date,
            })
            .collect();

        let (effective_start, effective_end) = match crate::cultivation_plan::calculators::effective_planning_period_calculator::calculate(
            &current_allocation,
            &input.moves,
            &cultivation_periods,
            snapshot.planning_period_boundaries.planning_start_date,
            snapshot.planning_period_boundaries.planning_end_date,
            self.clock.today(),
        ) {
            Ok(period) => period,
            Err(e) => {
                self.logger.error(&format!("❌ [Adjust] planning period: {e}"));
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_INVALID_DATE.into(),
                    message: self.translator.translate(
                        "api.errors.common.invalid_date_format",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                });
                return Ok(());
            }
        };

        let weather_data = json!({ "data": [] });

        match self.adjust_gateway.adjust(
            &current_allocation,
            &input.moves,
            &fields,
            &crops,
            &weather_data,
            effective_start,
            effective_end,
            interaction_rules_value.as_ref(),
            "maximize_profit",
            None,
            true,
        ) {
            Ok(result) => {
                let has_schedules = result
                    .get("field_schedules")
                    .map(|v| !v.as_array().map(|a| a.is_empty()).unwrap_or(true))
                    .unwrap_or(false);
                if !has_schedules {
                    self.emit_failure(PlanAllocationAdjustFailure {
                        kind: PlanAllocationAdjustFailure::KIND_RESULT_EMPTY.into(),
                        message: self.translator.translate(
                            "api.errors.optimization.result_empty",
                            &crate::shared::ports::translator_port::TranslateOptions::new(),
                        ),
                    });
                    return Ok(());
                }
                let summary = self
                    .read_gateway
                    .plan_summary_for_adjust_response(input.plan_id)?;
                let mut payload = summary;
                if let Some(profit) = result.get("total_profit") {
                    if let Some(obj) = payload.as_object_mut() {
                        obj.insert("total_profit".into(), profit.clone());
                    }
                }
                self.optimization_events_gateway
                    .broadcast_optimization_complete(input.plan_id, "adjusted")?;
                self.output_port.on_success(PlanAllocationAdjustOutput {
                    message: self.translator.translate(
                        "optimization.messages.adjust_completed",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                    skipped: false,
                    payload: Some(payload),
                    adjust_result: Some(result),
                });
                Ok(())
            }
            Err(e) => {
                self.logger.error(&format!("❌ [Adjust] Failed to adjust: {e}"));
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert("message".into(), e.to_string());
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_ADJUST_EXECUTION_FAILED.into(),
                    message: self.translator.translate(
                        "api.errors.optimization.adjust_failed",
                        &opts,
                    ),
                });
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_plan_allocation_adjust_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_allocation_adjust_interactor_test.rs"));
}
