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

pub struct SystemClock;

impl ClockPort for SystemClock {
    fn today(&self) -> Date {
        OffsetDateTime::now_utc().date()
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}
