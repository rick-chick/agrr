// Tests for `interactors/task_schedule_item_update_interactor.rs`.

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::TaskScheduleItemUpdateInteractor;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::attr::AttrMap;
use crate::shared::ports::ClockPort;
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use time::{Date, Month, OffsetDateTime};

struct FakeClock;
impl ClockPort for FakeClock {
    fn today(&self) -> Date {
        Date::from_calendar_date(2026, Month::June, 12).unwrap()
    }
    fn now(&self) -> OffsetDateTime {
        time::macros::datetime!(2026-06-12 12:00 UTC)
    }
}

struct SpyOutput {
    events: Arc<Mutex<Vec<String>>>,
}
impl TaskScheduleItemMutationOutputPort for SpyOutput {
    fn on_created(&mut self, _: Value) {}
    fn on_success(&mut self, _: Value) {
        self.events.lock().unwrap().push("success".into());
    }
    fn on_record_invalid(&mut self, _: BTreeMap<String, Vec<String>>, _: &str) {}
    fn on_not_found(&mut self) {
        self.events.lock().unwrap().push("not_found".into());
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
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubMutationGateway {
    update_calls: Arc<Mutex<u32>>,
}
impl TaskScheduleItemMutationGateway for StubMutationGateway {
    fn find_field_cultivation_for_create(
        &self,
        _: i64,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::TaskScheduleFieldCultivationSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
    fn find_agricultural_task_for_mutation(
        &self,
        _: Option<i64>,
    ) -> Result<
        Option<crate::cultivation_plan::dtos::TaskScheduleAgriculturalTaskSnapshot>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
    fn find_item_amount_snapshot(
        &self,
        _: i64,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::TaskScheduleItemAmountSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
    fn create(
        &self,
        _: i64,
        _: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_item_for_plan(
        &self,
        _: i64,
        _: i64,
        _: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        *self.update_calls.lock().unwrap() += 1;
        unimplemented!()
    }
    fn skip_item_for_plan(
        &self,
        _: i64,
        _: i64,
        _: OffsetDateTime,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn unskip_item_for_plan(
        &self,
        _: i64,
        _: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn deletion_undo_schedule_row_for_item(
        &self,
        _: i64,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::TaskScheduleItemDeletionUndoScheduleRow,
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
fn dispatches_not_found_when_org_member_updates_other_users_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let update_calls = Arc::new(Mutex::new(0));
    let mutation = StubMutationGateway {
        update_calls: Arc::clone(&update_calls),
    };
    let plan_gateway = StubPlanGateway {
        plan: org_scoped_private_plan(2, 5, 42),
    };
    let scope = MemberScopeGateway {
        org_ids: vec![42],
    };
    let mut interactor = TaskScheduleItemUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &mutation,
        &FakeClock,
        &scope,
    );

    interactor
        .call_rescuing(99, 2, 9, BTreeMap::new())
        .expect("call");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
    assert_eq!(0, *update_calls.lock().unwrap());
}
