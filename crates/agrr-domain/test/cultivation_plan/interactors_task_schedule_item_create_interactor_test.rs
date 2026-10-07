// Tests for `interactors/task_schedule_item_create_interactor.rs`.

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::TaskScheduleItemCreateInteractor;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::attr::AttrMap;
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

struct SpyOutput {
    events: Arc<Mutex<Vec<String>>>,
}
impl TaskScheduleItemMutationOutputPort for SpyOutput {
    fn on_created(&mut self, _: Value) {
        self.events.lock().unwrap().push("created".into());
    }
    fn on_success(&mut self, _: Value) {
        self.events.lock().unwrap().push("success".into());
    }
    fn on_record_invalid(&mut self, _: BTreeMap<String, Vec<String>>, _: &str) {
        self.events.lock().unwrap().push("record_invalid".into());
    }
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
    create_calls: Arc<Mutex<u32>>,
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
        *self.create_calls.lock().unwrap() += 1;
        unimplemented!()
    }
    fn update_item_for_plan(
        &self,
        _: i64,
        _: i64,
        _: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn skip_item_for_plan(
        &self,
        _: i64,
        _: i64,
        _: time::OffsetDateTime,
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
fn dispatches_not_found_when_org_member_creates_on_other_users_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let create_calls = Arc::new(Mutex::new(0));
    let mutation = StubMutationGateway {
        create_calls: Arc::clone(&create_calls),
    };
    let plan_gateway = StubPlanGateway {
        plan: org_scoped_private_plan(2, 5, 42),
    };
    let scope = MemberScopeGateway {
        org_ids: vec![42],
    };
    let mut interactor = TaskScheduleItemCreateInteractor::new(
        &mut output,
        &plan_gateway,
        &mutation,
        &scope,
    );

    interactor
        .call(99, 2, AttrMap::new())
        .expect("call");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
    assert_eq!(0, *create_calls.lock().unwrap());
}
