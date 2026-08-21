//! Thin edge adapters implementing domain ports (no business rules).

use agrr_domain::shared::ports::logger_port::LoggerPort;
use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use agrr_domain::shared::ports::ClockPort;
use time::{Date, OffsetDateTime};

pub struct NoopLogger;

impl LoggerPort for NoopLogger {
    fn info(&self, _message: &str) {}
    fn warn(&self, _message: &str) {}
    fn error(&self, _message: &str) {}
    fn debug(&self, _message: &str) {}
}

/// Writes domain logger lines to stderr (captured in `/tmp/agrr-strangler-pids/rust.log`).
#[derive(Clone, Copy, Default)]
pub struct StderrLogger;

impl LoggerPort for StderrLogger {
    fn info(&self, message: &str) {
        eprintln!("{message}");
    }

    fn warn(&self, message: &str) {
        eprintln!("WARN: {message}");
    }

    fn error(&self, message: &str) {
        eprintln!("ERROR: {message}");
    }

    fn debug(&self, message: &str) {
        eprintln!("DEBUG: {message}");
    }
}

pub struct PassthroughTranslator;

impl TranslatorPort for PassthroughTranslator {
    fn translate(&self, key: &str, _options: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(&self, date: Date, _format: Option<&str>, _options: &TranslateOptions) -> String {
        date.to_string()
    }
}

pub struct NoopOptimizationEventsGateway;

impl agrr_domain::cultivation_plan::gateways::CultivationPlanOptimizationEventsGateway
    for NoopOptimizationEventsGateway
{
    fn broadcast_field_added(
        &self,
        _plan_id: i64,
        _plan_type: &str,
        _field_snapshot: &agrr_domain::cultivation_plan::dtos::CultivationPlanFieldSnapshot,
        _total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn broadcast_field_removed(
        &self,
        _plan_id: i64,
        _plan_type: &str,
        _field_id: i64,
        _total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn broadcast_optimization_complete(
        &self,
        _plan_id: i64,
        _status: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }
}

/// Private plans use Cable; public plan mutations keep Noop (public Cable out of scope).
pub enum CultivationPlanOptimizationEventsAdapter {
    Cable(crate::cable::CableCultivationPlanOptimizationEventsGateway),
    Noop(NoopOptimizationEventsGateway),
}

impl agrr_domain::cultivation_plan::gateways::CultivationPlanOptimizationEventsGateway
    for CultivationPlanOptimizationEventsAdapter
{
    fn broadcast_field_added(
        &self,
        plan_id: i64,
        plan_type: &str,
        field_snapshot: &agrr_domain::cultivation_plan::dtos::CultivationPlanFieldSnapshot,
        total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self {
            Self::Cable(gateway) => gateway.broadcast_field_added(plan_id, plan_type, field_snapshot, total_area),
            Self::Noop(gateway) => gateway.broadcast_field_added(plan_id, plan_type, field_snapshot, total_area),
        }
    }

    fn broadcast_field_removed(
        &self,
        plan_id: i64,
        plan_type: &str,
        field_id: i64,
        total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self {
            Self::Cable(gateway) => gateway.broadcast_field_removed(plan_id, plan_type, field_id, total_area),
            Self::Noop(gateway) => gateway.broadcast_field_removed(plan_id, plan_type, field_id, total_area),
        }
    }

    fn broadcast_optimization_complete(
        &self,
        plan_id: i64,
        status: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self {
            Self::Cable(gateway) => gateway.broadcast_optimization_complete(plan_id, status),
            Self::Noop(gateway) => gateway.broadcast_optimization_complete(plan_id, status),
        }
    }
}

pub fn cultivation_plan_optimization_events_adapter(
    state: &crate::state::AppState,
    auth: &agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth,
) -> CultivationPlanOptimizationEventsAdapter {
    if auth.is_private() {
        CultivationPlanOptimizationEventsAdapter::Cable(
            crate::cable::CableCultivationPlanOptimizationEventsGateway::new(
                state.cable_hub.clone(),
                state.sqlite.clone(),
            ),
        )
    } else {
        CultivationPlanOptimizationEventsAdapter::Noop(NoopOptimizationEventsGateway)
    }
}

pub struct SystemClock;

impl ClockPort for SystemClock {
    fn today(&self) -> Date {
        OffsetDateTime::now_utc().date()
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}

#[cfg(test)]
mod cultivation_plan_optimization_events_adapter_tests {
    use super::*;
    use crate::test_support::test_app_state;
    use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;

    #[test]
    fn uses_cable_gateway_for_private_plan_mutations() {
        let db = crate::test_support::test_pool_with_plan(1);
        let state = test_app_state(db.pool);
        let auth = CultivationPlanRestAuth::private(1);

        let adapter = cultivation_plan_optimization_events_adapter(&state, &auth);

        assert!(matches!(
            adapter,
            CultivationPlanOptimizationEventsAdapter::Cable(_)
        ));
    }

    #[test]
    fn uses_noop_gateway_for_public_plan_mutations() {
        let db = crate::test_support::test_pool_with_plan(1);
        let state = test_app_state(db.pool);
        let auth = CultivationPlanRestAuth::public();

        let adapter = cultivation_plan_optimization_events_adapter(&state, &auth);

        assert!(matches!(
            adapter,
            CultivationPlanOptimizationEventsAdapter::Noop(_)
        ));
    }
}
