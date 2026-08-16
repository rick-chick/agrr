// Tests for `interactors/weather_reschedule_proposal_preview_interactor.rs`.

use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::{
    WeatherRescheduleCultivationSnapshot, WeatherRescheduleProposalContext,
};
use crate::cultivation_plan::dtos::{
    PlanAllocationAdjustFailure, PlanAllocationAdjustReadSnapshot, WeatherRescheduleProposalPreviewRead,
};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, CultivationPlanGateway, CultivationPlanOptimizationEventsGateway,
    PlanAllocationAdjustDebugDumpNullGateway, PlanAllocationAdjustGateway,
    PlanAllocationAdjustReadGateway, WeatherPredictionService, WeatherRescheduleProposalReadGateway,
};
use crate::cultivation_plan::interactors::WeatherRescheduleProposalPreviewInteractor;
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    WeatherForecastDay, WeatherRescheduleTaskSchedule,
};
use crate::cultivation_plan::ports::WeatherRescheduleProposalPreviewOutputPort;
use crate::field_cultivation::dtos::FieldCultivationSyncInput;
use crate::field_cultivation::ports::FieldCultivationSyncInputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use crate::shared::user::User;
use crate::weather_data::dtos::{CultivationPlanWeather, WeatherLocation};
use std::sync::{Arc, Mutex};
use time::{Date, Month, OffsetDateTime};

struct EmptyScopeGateway;
impl UserOrganizationScopeGateway for EmptyScopeGateway {
    fn organization_ids_for_user(
        &self,
        _: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
}

struct FakeUserLookup {
    user: User,
}

impl UserLookupGateway for FakeUserLookup {
    fn find(&self, _: i64) -> User {
        self.user.clone()
    }
}

struct FakeTranslator;
impl TranslatorPort for FakeTranslator {
    fn translate(
        &self,
        key: &str,
        options: &crate::shared::ports::translator_port::TranslateOptions,
    ) -> String {
        let mut parts = vec![key.to_string()];
        for (k, v) in options {
            parts.push(format!("{k}={v}"));
        }
        parts.join(":")
    }

    fn localize(
        &self,
        _: Date,
        _: Option<&str>,
        _: &crate::shared::ports::translator_port::TranslateOptions,
    ) -> String {
        String::new()
    }
}

struct FakeLogger;
impl LoggerPort for FakeLogger {
    fn info(&self, _: &str) {}
    fn warn(&self, _: &str) {}
    fn error(&self, _: &str) {}
    fn debug(&self, _: &str) {}
}

struct FakeClock;
impl ClockPort for FakeClock {
    fn today(&self) -> Date {
        Date::from_calendar_date(2026, Month::January, 1).unwrap()
    }
    fn now(&self) -> OffsetDateTime {
        time::macros::datetime!(2026-01-01 12:00 UTC)
    }
}

struct SpyPreviewOutput {
    previews: Arc<Mutex<Vec<WeatherRescheduleProposalPreviewRead>>>,
    failures: Arc<Mutex<Vec<PlanAllocationAdjustFailure>>>,
}

impl WeatherRescheduleProposalPreviewOutputPort for SpyPreviewOutput {
    fn on_success(&mut self, preview: WeatherRescheduleProposalPreviewRead) {
        self.previews.lock().unwrap().push(preview);
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
        organization_id: None,
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
    ) -> Result<
        Vec<crate::cultivation_plan::entities::FieldCultivationEntity>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
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
        _: &User,
        _: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete(
        &self,
        _: i64,
        _: &User,
        _: &str,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubWeatherProposalReadGateway {
    context: WeatherRescheduleProposalContext,
}

impl WeatherRescheduleProposalReadGateway for StubWeatherProposalReadGateway {
    fn find_context_by_plan_id(
        &self,
        _: i64,
    ) -> Result<WeatherRescheduleProposalContext, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.context.clone())
    }
}

struct StubAdjustReadGateway {
    snapshot: PlanAllocationAdjustReadSnapshot,
}

impl PlanAllocationAdjustReadGateway for StubAdjustReadGateway {
    fn find_adjust_read_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<PlanAllocationAdjustReadSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.snapshot.clone())
    }
    fn list_historical_weather_rows(
        &self,
        _: Option<i64>,
        _: Date,
        _: Date,
    ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
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
        _: Date,
        _: Date,
        _: Option<&serde_json::Value>,
        _: &str,
        _: Option<i64>,
        _: bool,
    ) -> Result<serde_json::Value, crate::cultivation_plan::errors::AdjustExecutionError> {
        unimplemented!("preview not_found tests should not reach adjust gateway")
    }
}

struct StubWeatherGateway;
struct StubWeatherService;
impl AdjustWeatherPredictionGateway for StubWeatherGateway {
    fn prediction_service(
        &self,
        _: &WeatherLocation,
    ) -> Result<Box<dyn WeatherPredictionService>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Box::new(StubWeatherService))
    }
}
impl WeatherPredictionService for StubWeatherService {
    fn get_existing_prediction(
        &self,
        _: Date,
        _: &CultivationPlanWeather,
    ) -> Option<serde_json::Value> {
        None
    }
    fn predict_for_cultivation_plan(
        &self,
        _: &CultivationPlanWeather,
        _: Option<Date>,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        Ok(serde_json::json!({"data": []}))
    }
}

struct StubFieldCultivationSync;
impl FieldCultivationSyncInputPort for StubFieldCultivationSync {
    fn call(
        &mut self,
        _: i64,
        _: FieldCultivationSyncInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
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

fn date(y: i32, m: u8, d: u8) -> Date {
    Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap()
}

fn frost_proposal_context() -> WeatherRescheduleProposalContext {
    WeatherRescheduleProposalContext {
        tasks: vec![WeatherRescheduleTaskSchedule {
            item_id: 42,
            field_cultivation_id: 100,
            scheduled_date: date(2026, 4, 10),
        }],
        current_forecast: vec![
            WeatherForecastDay {
                date: date(2026, 4, 10),
                t_min: -2.0,
                t_mean: Some(5.0),
            },
            WeatherForecastDay {
                date: date(2026, 4, 11),
                t_min: 2.0,
                t_mean: Some(8.0),
            },
        ],
        previous_forecast: vec![],
        gdd_samples: vec![],
        cultivations: vec![WeatherRescheduleCultivationSnapshot {
            field_cultivation_id: 100,
            plan_field_id: 7,
            start_date: Some(date(2026, 4, 1)),
            completion_date: Some(date(2026, 8, 31)),
            crop_name: "Tomato".into(),
            field_name: "North Field".into(),
            frost_threshold: Some(0.0),
        }],
    }
}

#[test]
fn call_returns_not_found_for_unknown_proposal_id() {
    let previews = Arc::new(Mutex::new(Vec::new()));
    let failures = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyPreviewOutput {
        previews: Arc::clone(&previews),
        failures: Arc::clone(&failures),
    };
    let plan_gateway = StubPlanGateway {
        plan: owned_plan(),
    };
    let weather_read_gateway = StubWeatherProposalReadGateway {
        context: frost_proposal_context(),
    };
    let adjust_read_gateway = StubAdjustReadGateway {
        snapshot: PlanAllocationAdjustReadSnapshot::minimal_for_tests(2, "Tomato", true),
    };
    let user_lookup = FakeUserLookup {
        user: User::new(1, false),
    };
    let mut field_cultivation_sync = StubFieldCultivationSync;
    let mut interactor = WeatherRescheduleProposalPreviewInteractor::new(
        &mut output,
        &FakeLogger,
        &FakeTranslator,
        &FakeClock,
        1,
        2,
        "missing:100:42".into(),
        &plan_gateway,
        &weather_read_gateway,
        &adjust_read_gateway,
        &StubAdjustGateway,
        &StubEventsGateway,
        &PlanAllocationAdjustDebugDumpNullGateway,
        &StubWeatherGateway,
        &mut field_cultivation_sync,
        "abcd1234",
        &user_lookup,
        &EmptyScopeGateway,
    );

    let err = interactor.call().unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
    assert!(previews.lock().unwrap().is_empty());
    assert!(failures.lock().unwrap().is_empty());
}

#[test]
fn call_returns_not_found_when_private_plan_owned_by_another_user() {
    let previews = Arc::new(Mutex::new(Vec::new()));
    let failures = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyPreviewOutput {
        previews: Arc::clone(&previews),
        failures: Arc::clone(&failures),
    };
    let mut other_plan = owned_plan();
    other_plan.user_id = 99;
    let plan_gateway = StubPlanGateway { plan: other_plan };
    let weather_read_gateway = StubWeatherProposalReadGateway {
        context: frost_proposal_context(),
    };
    let adjust_read_gateway = StubAdjustReadGateway {
        snapshot: PlanAllocationAdjustReadSnapshot::minimal_for_tests(2, "Tomato", true),
    };
    let user_lookup = FakeUserLookup {
        user: User::new(1, false),
    };
    let mut field_cultivation_sync = StubFieldCultivationSync;
    let mut interactor = WeatherRescheduleProposalPreviewInteractor::new(
        &mut output,
        &FakeLogger,
        &FakeTranslator,
        &FakeClock,
        1,
        2,
        "frost_forecast:100:42".into(),
        &plan_gateway,
        &weather_read_gateway,
        &adjust_read_gateway,
        &StubAdjustGateway,
        &StubEventsGateway,
        &PlanAllocationAdjustDebugDumpNullGateway,
        &StubWeatherGateway,
        &mut field_cultivation_sync,
        "abcd1234",
        &user_lookup,
        &EmptyScopeGateway,
    );

    let err = interactor.call().unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
}
