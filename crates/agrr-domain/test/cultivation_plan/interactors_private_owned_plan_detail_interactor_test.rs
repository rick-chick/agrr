// Tests for `interactors/private_owned_plan_detail_interactor.rs`.

use crate::crop::gateways::crop_gateway_stub::CropGatewayStub;
use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::dtos::PrivatePlanReadSnapshot;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway,
};
use crate::cultivation_plan::interactors::PrivateOwnedPlanDetailInteractor;
use crate::cultivation_plan::ports::PrivateOwnedPlanDetailOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::shared::ports::translator_port::TranslateOptions;
use crate::shared::user::User;
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

struct SpyOutput {
    events: Arc<Mutex<Vec<String>>>,
}
impl PrivateOwnedPlanDetailOutputPort for SpyOutput {
    fn on_success(&mut self, _: crate::cultivation_plan::dtos::PrivateCultivationPlanDetail) {
        self.events.lock().unwrap().push("success".into());
    }
    fn on_not_found(&mut self) {
        self.events.lock().unwrap().push("not_found".into());
    }
    fn on_failure(&mut self, _: crate::shared::dtos::Error) {
        self.events.lock().unwrap().push("failure".into());
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

struct StubPrivateReadGateway;
impl CultivationPlanPrivateSnapshotReadGateway for StubPrivateReadGateway {
    fn find_task_schedule_timeline_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::TaskScheduleTimelineSnapshot,
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
    fn find_plan_read_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<PrivatePlanReadSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Ok(PrivatePlanReadSnapshot {
            id: 2,
            display_name: "Plan".into(),
            farm_display_name: "Farm".into(),
            total_area: 1.0,
            field_cultivations_count: 0,
            cultivation_plan_fields_count: 0,
            planning_start_date: None,
            planning_end_date: None,
            status: "completed".into(),
            field_cultivations: vec![],
            cultivation_plan_fields: vec![],
            palette_used_crop_ids: vec![],
        })
    }
}

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/test/cultivation_plan/member_scope_test_fixtures.inc.rs"
));

#[test]
fn call_catch_all_not_found_when_org_member_views_other_users_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
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
    let mut interactor = PrivateOwnedPlanDetailInteractor::new(
        &mut output,
        99,
        &StubPrivateReadGateway,
        &plan_gateway,
        &CropGatewayStub,
        &FakeTranslator,
        &FakeLogger,
        &user_lookup,
        &scope,
    );

    interactor.call_catch_all(2).expect("call");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
}
