// Tests for `interactors/task_schedule_timeline_interactor.rs`.

use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::TaskScheduleTimelineSnapshot;
use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway,
};
use crate::cultivation_plan::interactors::TaskScheduleTimelineInteractor;
use crate::cultivation_plan::ports::TaskScheduleTimelineOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use crate::shared::ports::translator_port::TranslateOptions;
use crate::shared::user::User;
use std::sync::{Arc, Mutex};
use time::{Date, Month, OffsetDateTime};

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

struct FakeClock;
impl ClockPort for FakeClock {
    fn today(&self) -> Date {
        Date::from_calendar_date(2026, Month::January, 1).unwrap()
    }
    fn now(&self) -> OffsetDateTime {
        time::macros::datetime!(2026-01-01 12:00 UTC)
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

struct SpyTimelineOutput {
    events: Arc<Mutex<Vec<String>>>,
}
impl TaskScheduleTimelineOutputPort for SpyTimelineOutput {
    fn on_success(&mut self, _: crate::cultivation_plan::dtos::TaskScheduleTimeline) {
        self.events.lock().unwrap().push("success".into());
    }
    fn on_failure(&mut self, _: crate::shared::dtos::Error) {
        self.events.lock().unwrap().push("failure".into());
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
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubSnapshotGateway {
    timeline_calls: Arc<Mutex<u32>>,
}
impl CultivationPlanPrivateSnapshotReadGateway for StubSnapshotGateway {
    fn find_task_schedule_timeline_by_plan_id(
        &self,
        _: i64,
    ) -> Result<TaskScheduleTimelineSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        *self.timeline_calls.lock().unwrap() += 1;
        unimplemented!()
    }
    fn find_plan_read_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::PrivatePlanReadSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
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

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/test/cultivation_plan/member_scope_test_fixtures.inc.rs"
));

#[test]
fn returns_not_found_when_org_member_reads_other_users_timeline() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyTimelineOutput {
        events: Arc::clone(&events),
    };
    let timeline_calls = Arc::new(Mutex::new(0));
    let snapshot_gateway = StubSnapshotGateway {
        timeline_calls: Arc::clone(&timeline_calls),
    };
    let plan_gateway = StubPlanGateway {
        plan: org_scoped_private_plan(2, 5, 42),
    };
    let scope = MemberScopeGateway {
        org_ids: vec![42],
    };
    let user_lookup = StubUserLookup {
        user: User::new(99, false),
    };
    let mut interactor = TaskScheduleTimelineInteractor::new(
        &mut output,
        99,
        2,
        &snapshot_gateway,
        &plan_gateway,
        &FakeTranslator,
        &FakeLogger,
        &user_lookup,
        &FakeClock,
        &scope,
    );

    let err = interactor.call().unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
    assert_eq!(0, *timeline_calls.lock().unwrap());
    assert!(events.lock().unwrap().is_empty());
}
