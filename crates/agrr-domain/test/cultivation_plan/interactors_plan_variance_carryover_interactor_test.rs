// Tests for `interactors/plan_variance_carryover_interactor.rs`.

use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineFieldRead, TaskScheduleTimelinePlanRead, TaskScheduleTimelineScheduleItemRead,
    TaskScheduleTimelineScheduleRead, TaskScheduleTimelineSnapshot,
    TaskScheduleTimelineWorkRecordSummaryRead,
};
use crate::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, PlanVarianceLearningSnapshotRead, PlanVsActualSummaryRead,
};
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway, PlanVarianceLearningGateway,
};
use crate::cultivation_plan::interactors::{
    PlanVarianceCarryoverInput, PlanVarianceCarryoverInteractor,
};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::shared::ports::translator_port::TranslateOptions;
use crate::shared::user::User;
use serde_json::Value;
use std::sync::{Arc, Mutex};
use time::Date;

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
        self.user
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

struct StubPlanGateway {
    plans: Vec<CultivationPlanEntity>,
}
impl CultivationPlanGateway for StubPlanGateway {
    fn find_by_id(
        &self,
        id: i64,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.plans
            .iter()
            .find(|plan| plan.id == id)
            .cloned()
            .ok_or_else(|| Box::new(RecordNotFoundError) as _)
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

struct StubSnapshotGateway {
    snapshot: TaskScheduleTimelineSnapshot,
}
impl CultivationPlanPrivateSnapshotReadGateway for StubSnapshotGateway {
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
        Ok(self.snapshot.clone())
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

struct SpyVarianceLearningGateway {
    saved: Arc<Mutex<Vec<(i64, i64, PlanVsActualSummaryRead)>>>,
}
impl PlanVarianceLearningGateway for SpyVarianceLearningGateway {
    fn save(
        &self,
        plan_id: i64,
        source_plan_id: i64,
        summary: &PlanVsActualSummaryRead,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.saved
            .lock()
            .unwrap()
            .push((plan_id, source_plan_id, summary.clone()));
        Ok(())
    }
    fn find_by_plan_id(
        &self,
        _: i64,
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(None)
    }
}

fn sample_snapshot() -> TaskScheduleTimelineSnapshot {
    TaskScheduleTimelineSnapshot {
        plan: TaskScheduleTimelinePlanRead {
            id: 1,
            display_name: "Source".into(),
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
        fields: vec![TaskScheduleTimelineFieldRead {
            id: 10,
            name: "F1".into(),
            crop_name: "Tomato".into(),
            area_sqm: 50.0,
            field_cultivation_id: 100,
            crop_id: 42,
            cultivation_start_date: None,
            cultivation_end_date: None,
            task_options: vec![],
            schedules: vec![TaskScheduleTimelineScheduleRead {
                category: "general".into(),
                items: vec![TaskScheduleTimelineScheduleItemRead {
                    id: 5,
                    name: "Weed".into(),
                    task_type: "field_work".into(),
                    scheduled_date: Some("2026-06-01".into()),
                    stage_name: None,
                    stage_order: None,
                    gdd_trigger: Some(100.0),
                    gdd_tolerance: None,
                    priority: None,
                    source: "agrr".into(),
                    weather_dependency: None,
                    time_per_sqm: None,
                    amount: None,
                    amount_unit: None,
                    status: "planned".into(),
                    agricultural_task_id: None,
                    field_cultivation_id: 100,
                    agricultural_task: None,
                    rescheduled_at: None,
                    cancelled_at: None,
                    completed: true,
                    work_records: vec![TaskScheduleTimelineWorkRecordSummaryRead {
                        id: 50,
                        actual_date: "2026-06-08".into(),
                        notes: None,
                        gdd_at_actual: Some(110.0),
                    }],
                }],
            }],
        }],
        scheduled_dates: vec![],
    }
}

#[test]
fn on_success_saves_variance_snapshot_with_new_plan_id() {
    let saved = Arc::new(Mutex::new(Vec::new()));
    let plan_gateway = StubPlanGateway {
        plans: vec![plan_entity(10, 7, 1), plan_entity(20, 7, 1)],
    };
    let snapshot_gateway = StubSnapshotGateway {
        snapshot: sample_snapshot(),
    };
    let variance_gateway = SpyVarianceLearningGateway {
        saved: Arc::clone(&saved),
    };
    let user_lookup = StubUserLookup {
        user: User::new(1, false),
    };
    let translator = FakeTranslator;
    let logger = FakeLogger;
    let scope = EmptyScopeGateway;

    let interactor = PlanVarianceCarryoverInteractor::new(
        &plan_gateway,
        &snapshot_gateway,
        &variance_gateway,
        &user_lookup,
        &scope,
        &translator,
        &logger,
    );

    interactor
        .call(PlanVarianceCarryoverInput {
            new_plan_id: 20,
            source_plan_id: 10,
            target_farm_id: 7,
            user_id: 1,
        })
        .expect("carryover succeeds");

    let entries = saved.lock().unwrap();
    assert_eq!(1, entries.len());
    assert_eq!(20, entries[0].0);
    assert_eq!(10, entries[0].1);
    assert_eq!(20, entries[0].2.plan_id);
    assert_eq!(1, entries[0].2.top_variance_items.len());
}

#[test]
fn denies_carryover_when_user_cannot_access_target_plan() {
    let saved = Arc::new(Mutex::new(Vec::new()));
    let plan_gateway = StubPlanGateway {
        plans: vec![plan_entity(10, 7, 1), plan_entity(20, 7, 2)],
    };
    let snapshot_gateway = StubSnapshotGateway {
        snapshot: sample_snapshot(),
    };
    let variance_gateway = SpyVarianceLearningGateway {
        saved: Arc::clone(&saved),
    };
    let user_lookup = StubUserLookup {
        user: User::new(1, false),
    };
    let translator = FakeTranslator;
    let logger = FakeLogger;
    let scope = EmptyScopeGateway;

    let interactor = PlanVarianceCarryoverInteractor::new(
        &plan_gateway,
        &snapshot_gateway,
        &variance_gateway,
        &user_lookup,
        &scope,
        &translator,
        &logger,
    );

    let err = interactor
        .call(PlanVarianceCarryoverInput {
            new_plan_id: 20,
            source_plan_id: 10,
            target_farm_id: 7,
            user_id: 1,
        })
        .expect_err("carryover to another user's plan must fail");

    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
    assert!(saved.lock().unwrap().is_empty());
}

#[test]
fn allows_carryover_from_source_on_different_farm_when_accessible() {
    let saved = Arc::new(Mutex::new(Vec::new()));
    let plan_gateway = StubPlanGateway {
        plans: vec![plan_entity(10, 99, 1), plan_entity(20, 7, 1)],
    };
    let snapshot_gateway = StubSnapshotGateway {
        snapshot: sample_snapshot(),
    };
    let variance_gateway = SpyVarianceLearningGateway {
        saved: Arc::clone(&saved),
    };
    let user_lookup = StubUserLookup {
        user: User::new(1, false),
    };
    let translator = FakeTranslator;
    let logger = FakeLogger;
    let scope = EmptyScopeGateway;

    let interactor = PlanVarianceCarryoverInteractor::new(
        &plan_gateway,
        &snapshot_gateway,
        &variance_gateway,
        &user_lookup,
        &scope,
        &translator,
        &logger,
    );

    interactor
        .call(PlanVarianceCarryoverInput {
            new_plan_id: 20,
            source_plan_id: 10,
            target_farm_id: 7,
            user_id: 1,
        })
        .expect("cross-farm carryover succeeds");

    assert_eq!(1, saved.lock().unwrap().len());
}
