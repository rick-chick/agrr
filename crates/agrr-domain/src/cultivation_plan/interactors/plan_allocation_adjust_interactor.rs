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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        CultivationPlanRestAuth, PlanAllocationAdjustPlanCropSnapshot,
        PlanAllocationAdjustReadSnapshot,
    };
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use crate::cultivation_plan::gateways::PlanAllocationAdjustDebugDumpNullGateway;
    use crate::shared::ports::translator_port::TranslateOptions;
    use serde_json::json;
    use std::sync::{Arc, Mutex};
    use time::macros::datetime;

    struct FakeTranslator;
    impl TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, options: &TranslateOptions) -> String {
            let mut parts = vec![key.to_string()];
            for (k, v) in options {
                parts.push(format!("{k}={v}"));
            }
            parts.join(":")
        }

        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FakeLogger {
        entries: Arc<Mutex<Vec<String>>>,
    }

    impl LoggerPort for FakeLogger {
        fn info(&self, message: &str) {
            self.entries.lock().unwrap().push(message.to_string());
        }
        fn warn(&self, message: &str) {
            self.info(message);
        }
        fn error(&self, message: &str) {
            self.info(message);
        }
        fn debug(&self, message: &str) {
            self.info(message);
        }
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            time::macros::date!(2026-01-01)
        }
        fn now(&self) -> time::OffsetDateTime {
            datetime!(2026-01-01 12:00 UTC)
        }
    }

    struct SpyOutput {
        success: Arc<Mutex<Vec<PlanAllocationAdjustOutput>>>,
        failures: Arc<Mutex<Vec<PlanAllocationAdjustFailure>>>,
    }

    impl PlanAllocationAdjustOutputPort for SpyOutput {
        fn on_success(&mut self, output: PlanAllocationAdjustOutput) {
            self.success.lock().unwrap().push(output);
        }
        fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
            self.failures.lock().unwrap().push(failure);
        }
    }

    fn owned_plan() -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 2,
            farm_id: 1,
            user_id: 1,
            total_area: 0.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: None,
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    fn other_users_plan() -> CultivationPlanEntity {
        let mut plan = owned_plan();
        plan.user_id = 99;
        plan
    }

    fn snapshot(crop_name: &str, has_growth_stages: bool) -> PlanAllocationAdjustReadSnapshot {
        PlanAllocationAdjustReadSnapshot::minimal_for_tests(2, crop_name, has_growth_stages)
    }

    struct StubPlanGateway {
        plan: CultivationPlanEntity,
    }

    impl CultivationPlanGateway for StubPlanGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.plan.clone())
        }
        fn create(
            &self,
            _: &crate::cultivation_plan::dtos::CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update(
            &self,
            _: i64,
            _: std::collections::HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<crate::cultivation_plan::entities::FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            block()
        }
        fn private_owned_plan_display_name(
            &self,
            _: &crate::shared::user::User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(
            &self,
            _: i64,
            _: &crate::shared::user::User,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct StubReadGateway {
        snapshot: PlanAllocationAdjustReadSnapshot,
        called: Arc<Mutex<bool>>,
    }

    impl PlanAllocationAdjustReadGateway for StubReadGateway {
        fn find_adjust_read_snapshot_by_plan_id(
            &self,
            _: i64,
        ) -> Result<PlanAllocationAdjustReadSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            *self.called.lock().unwrap() = true;
            Ok(self.snapshot.clone())
        }
        fn list_historical_weather_rows(
            &self,
            _: Option<i64>,
            _: time::Date,
            _: time::Date,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn plan_summary_for_adjust_response(
            &self,
            _: i64,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct StubAdjustGateway;
    impl PlanAllocationAdjustGateway for StubAdjustGateway {
        fn adjust(
            &self,
            _: &serde_json::Value,
            _: &[serde_json::Value],
            _: &[serde_json::Value],
            _: &[serde_json::Value],
            _: &serde_json::Value,
            _: time::Date,
            _: time::Date,
            _: Option<&serde_json::Value>,
            _: &str,
            _: Option<i64>,
            _: bool,
        ) -> Result<serde_json::Value, crate::cultivation_plan::errors::AdjustExecutionError>
        {
            unimplemented!()
        }
    }

    struct StubEventsGateway;
    impl CultivationPlanOptimizationEventsGateway for StubEventsGateway {
        fn broadcast_field_added(
            &self,
            _: i64,
            _: &str,
            _: &crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot,
            _: f64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn broadcast_field_removed(
            &self,
            _: i64,
            _: &str,
            _: i64,
            _: f64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn broadcast_optimization_complete(
            &self,
            _: i64,
            _: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    // Ruby: test "call loads adjust read snapshot after RestPlanAccess for private auth"
    #[test]
    fn call_loads_adjust_read_snapshot_after_rest_plan_access_for_private_auth() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let read_called = Arc::new(Mutex::new(false));
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: owned_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("C", true),
            called: Arc::clone(&read_called),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(*read_called.lock().unwrap());
        let successes = success.lock().unwrap();
        assert_eq!(successes.len(), 1);
        assert!(successes[0].skipped);
        assert!(successes[0].message.contains("調整不要"));
        assert!(failures.lock().unwrap().is_empty());
    }

    // Ruby: test "call dispatches not_found when private auth and plan owned by another user"
    #[test]
    fn call_dispatches_not_found_when_private_auth_and_plan_owned_by_another_user() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let read_called = Arc::new(Mutex::new(false));
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: other_users_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("C", true),
            called: Arc::clone(&read_called),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(!*read_called.lock().unwrap());
        assert!(success.lock().unwrap().is_empty());
        let failure = failures.lock().unwrap();
        assert_eq!(failure.len(), 1);
        assert_eq!(failure[0].kind, PlanAllocationAdjustFailure::KIND_NOT_FOUND);
    }

    // Ruby: test "call dispatches crop_missing_growth_stages when plan crop has no growth stages"
    #[test]
    fn call_dispatches_crop_missing_growth_stages_when_plan_crop_has_no_growth_stages() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: owned_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("X", false),
            called: Arc::new(Mutex::new(false)),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(success.lock().unwrap().is_empty());
        let failure = failures.lock().unwrap();
        assert_eq!(failure.len(), 1);
        assert_eq!(
            failure[0].kind,
            PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES
        );
        assert!(failure[0].message.contains("crop_name=X"));
    }
}
