// Tests for `interactors/work_record_photo_upload_complete_interactor.rs`.

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::ports::ClockPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoObjectStoreGateway, WorkRecordPhotoRow,
};
use crate::work_record::ports::WorkRecordPhotoUploadCompleteOutputPort;
use serde_json::Value;
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
impl WorkRecordPhotoUploadCompleteOutputPort for SpyOutput {
    fn on_success(&mut self, _: crate::work_record::dtos::WorkRecordPhotoRead) {
        self.events.lock().unwrap().push("success".into());
    }
    fn on_not_found(&mut self) {
        self.events.lock().unwrap().push("not_found".into());
    }
    fn on_record_invalid(&mut self, _: std::collections::BTreeMap<String, Vec<String>>, _: &str) {}
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

struct StubPhotoGateway {
    find_calls: Arc<Mutex<u32>>,
}
impl WorkRecordPhotoGateway for StubPhotoGateway {
    fn count_for_record(
        &self,
        _: i64,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }
    fn count_ready_for_record(
        &self,
        _: i64,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }
    fn insert_pending(
        &self,
        _: i64,
        _: i64,
        _: &str,
        _: &str,
        _: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn insert_pending_under_limit(
        &self,
        _: i64,
        _: i64,
        _: &str,
        _: &str,
        _: i32,
        _: OffsetDateTime,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_for_record(
        &self,
        _: i64,
        _: i64,
        _: i64,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        *self.find_calls.lock().unwrap() += 1;
        Err(RecordNotFoundError.into())
    }
    fn mark_ready(
        &self,
        _: i64,
        _: i64,
        _: i64,
        _: i64,
        _: i32,
        _: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn mark_ready_under_limit(
        &self,
        _: i64,
        _: i64,
        _: i64,
        _: i64,
        _: i32,
        _: OffsetDateTime,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn touch_pending_updated_at(
        &self,
        _: i64,
        _: i64,
        _: i64,
        _: OffsetDateTime,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete(
        &self,
        _: i64,
        _: i64,
        _: i64,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn list_ready_for_plan(
        &self,
        _: i64,
        _: &[i64],
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
    fn work_record_exists(
        &self,
        _: i64,
        _: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        Ok(true)
    }
    fn delete_stale_pending_older_than(
        &self,
        _: i64,
        _: i64,
        _: OffsetDateTime,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }
}

struct StubObjectStore;
impl WorkRecordPhotoObjectStoreGateway for StubObjectStore {
    fn write_object(
        &self,
        _: &str,
        _: &str,
        _: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn read_object(
        &self,
        _: &str,
    ) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn delete_object(&self, _: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/test/cultivation_plan/member_scope_test_fixtures.inc.rs"
));

#[test]
fn complete_not_found_when_org_member_on_other_users_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let find_calls = Arc::new(Mutex::new(0));
    let photo_gateway = StubPhotoGateway {
        find_calls: Arc::clone(&find_calls),
    };
    let plan_gateway = StubPlanGateway {
        plan: org_scoped_private_plan(1, 5, 42),
    };
    let read_url_builder = |_: i64, _: i64, _: i64| "/read".into();
    let scope = MemberScopeGateway {
        org_ids: vec![42],
    };
    let mut interactor = super::WorkRecordPhotoUploadCompleteInteractor::new(
        &mut output,
        &plan_gateway,
        &photo_gateway,
        &StubObjectStore,
        &FakeClock,
        &read_url_builder,
        &scope,
    );

    interactor
        .call_rescuing(99, 1, 42, 7, 100)
        .expect("call");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
    assert_eq!(0, *find_calls.lock().unwrap());
}
