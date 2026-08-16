// Tests for `interactors/variance_portfolio_interactor.rs`.

use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineSnapshot, TaskScheduleTimelinePlanRead,
};
use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::{
    WeatherRescheduleCultivationSnapshot, WeatherRescheduleProposalContext,
};
use crate::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, PrivatePlanIndexPlanRow,
};
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateReadGateway,
    CultivationPlanPrivateSnapshotReadGateway, PlanVarianceLearningGateway,
    WeatherRescheduleProposalReadGateway,
};
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    WeatherForecastDay, WeatherRescheduleTaskSchedule,
};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::shared::ports::translator_port::TranslateOptions;
use crate::shared::user::User;
use crate::work_record::dtos::VariancePortfolioRow;
use crate::work_record::interactors::VariancePortfolioInteractor;
use crate::work_record::ports::VariancePortfolioOutputPort;
use serde_json::Value;
use std::sync::{Arc, Mutex};
use time::{Date, Month};

struct FakeTranslator;
impl TranslatorPort for FakeTranslator {
    fn translate(&self, key: &str, _: &TranslateOptions) -> String {
        key.to_string()
    }
    fn localize(&self, _: Date, _: Option<&str>, _: &TranslateOptions) -> String {
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

struct EmptyScopeGateway;
impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
    fn organization_ids_for_user(
        &self,
        _: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
}

struct StubUserLookup {
    user: User,
}
impl UserLookupGateway for StubUserLookup {
    fn find(&self, _: i64) -> User {
        self.user.clone()
    }
}

fn date(y: i32, m: u8, d: u8) -> Date {
    Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap()
}

fn plan_row(id: i64, farm_id: i64) -> PrivatePlanIndexPlanRow {
    PrivatePlanIndexPlanRow {
        id,
        farm_id,
        farm_display_name: format!("Farm {farm_id}"),
        total_area: 10.0,
        crops_count: 1,
        fields_count: 1,
        status: "completed".into(),
        display_name: format!("Plan {id}"),
        created_at: "2026-01-01".into(),
        plan_year: Some(2026),
    }
}

fn plan_entity(id: i64, farm_id: i64, user_id: i64) -> CultivationPlanEntity {
    CultivationPlanEntity {
        id,
        farm_id,
        user_id,
        organization_id: None,
        total_area: 50.0,
        plan_type: "private".into(),
        plan_year: Some(2026),
        plan_name: Some("Plan".into()),
        planning_start_date: None,
        planning_end_date: None,
        status: Some("completed".into()),
        session_id: None,
        display_name: None,
        optimization_phase: None,
        optimization_phase_message: None,
        cultivation_plan_crops_count: 1,
        cultivation_plan_fields_count: 1,
        created_at: None,
        updated_at: None,
    }
}

struct StubPrivateReadGateway {
    rows: Vec<PrivatePlanIndexPlanRow>,
}
impl CultivationPlanPrivateReadGateway for StubPrivateReadGateway {
    fn list_private_plan_index_rows_by_user_id(
        &self,
        _: i64,
    ) -> Result<Vec<PrivatePlanIndexPlanRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.rows.clone())
    }
}

struct StubPrivateSnapshotGateway;
impl CultivationPlanPrivateSnapshotReadGateway for StubPrivateSnapshotGateway {
    fn find_plan_read_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::PrivatePlanReadSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn find_task_schedule_timeline_by_plan_id(
        &self,
        _: i64,
    ) -> Result<TaskScheduleTimelineSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Ok(TaskScheduleTimelineSnapshot {
            plan: TaskScheduleTimelinePlanRead {
                id: 1,
                display_name: "Plan".into(),
                status: "completed".into(),
                planning_start_date: None,
                planning_end_date: None,
                timeline_generated_at: None,
                farm_display_name: "Farm".into(),
                total_area: 50.0,
                task_schedule_sync_state: "ready".into(),
                task_schedule_sync_error: None,
                task_schedule_sync_error_crop_id: None,
            },
            fields: vec![],
            scheduled_dates: vec![],
        })
    }

    fn find_optimization_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::OptimizationPlanSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
}

struct StubVarianceLearningGateway;
impl PlanVarianceLearningGateway for StubVarianceLearningGateway {
    fn save(
        &self,
        _: i64,
        _: i64,
        _: &crate::cultivation_plan::dtos::PlanVsActualSummaryRead,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        Option<crate::cultivation_plan::dtos::PlanVarianceLearningSnapshotRead>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Ok(None)
    }

    fn find_proposal_application_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<std::collections::BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(std::collections::BTreeMap::new())
    }

    fn upsert_proposal_application_progress(
        &self,
        _: i64,
        _: &std::collections::BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn find_reorganize_orchestration_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Ok(crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead::default())
    }

    fn upsert_reorganize_orchestration_progress(
        &self,
        _: i64,
        _: &crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressPatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn find_learn_handoff_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::LearnHandoffStateRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Ok(crate::cultivation_plan::dtos::LearnHandoffStateRead::default())
    }

    fn patch_learn_handoff(
        &self,
        _: i64,
        _: &crate::cultivation_plan::dtos::LearnHandoffStatePatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }
}

struct StubPlanGateway {
    user_id: i64,
}
impl CultivationPlanGateway for StubPlanGateway {
    fn find_by_id(
        &self,
        id: i64,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(plan_entity(id, id + 100, self.user_id))
    }
    fn create(
        &self,
        _: &CultivationPlanCreateAttrs,
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
    ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
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
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubWeatherReadGateway {
    contexts: std::collections::HashMap<i64, WeatherRescheduleProposalContext>,
}
impl WeatherRescheduleProposalReadGateway for StubWeatherReadGateway {
    fn find_context_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<WeatherRescheduleProposalContext, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self
            .contexts
            .get(&plan_id)
            .cloned()
            .unwrap_or_else(empty_weather_context))
    }
}

fn empty_weather_context() -> WeatherRescheduleProposalContext {
    WeatherRescheduleProposalContext {
        tasks: vec![],
        current_forecast: vec![],
        previous_forecast: vec![],
        gdd_samples: vec![],
        cultivations: vec![],
    }
}

fn frost_trigger_context() -> WeatherRescheduleProposalContext {
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

struct SpyOutput {
    rows: Arc<Mutex<Option<Vec<VariancePortfolioRow>>>>,
}
impl VariancePortfolioOutputPort for SpyOutput {
    fn on_success(&mut self, rows: Vec<VariancePortfolioRow>) {
        *self.rows.lock().unwrap() = Some(rows);
    }
    fn on_failure(&mut self, _: crate::shared::dtos::Error) {
        panic!("unexpected failure");
    }
}

#[test]
fn includes_weather_trigger_count_from_proposals_per_plan() {
    let user = User::new(1, false);
    let mut contexts = std::collections::HashMap::new();
    contexts.insert(9, frost_trigger_context());
    contexts.insert(10, empty_weather_context());

    let mut output = SpyOutput {
        rows: Arc::new(Mutex::new(None)),
    };
    let private_read = StubPrivateReadGateway {
        rows: vec![plan_row(9, 5), plan_row(10, 6)],
    };
    let private_snapshot = StubPrivateSnapshotGateway;
    let variance_learning = StubVarianceLearningGateway;
    let plan_gateway = StubPlanGateway { user_id: user.id };
    let weather_read = StubWeatherReadGateway { contexts };
    let translator = FakeTranslator;
    let logger = FakeLogger;
    let user_lookup = StubUserLookup { user };
    let scope_gateway = EmptyScopeGateway;

    let mut interactor = VariancePortfolioInteractor::new(
        &mut output,
        user.id,
        &private_read,
        &private_snapshot,
        &variance_learning,
        &plan_gateway,
        &translator,
        &logger,
        &user_lookup,
        &scope_gateway,
        &weather_read,
    );

    interactor.call().expect("interactor succeeds");

    let rows = output.rows.lock().unwrap().clone().expect("rows emitted");
    assert_eq!(rows.len(), 2);
    let plan_9 = rows.iter().find(|row| row.plan_id == 9).expect("plan 9 row");
    let plan_10 = rows.iter().find(|row| row.plan_id == 10).expect("plan 10 row");
    assert_eq!(1, plan_9.weather_trigger_count);
    assert_eq!(0, plan_10.weather_trigger_count);
}
