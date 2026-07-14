// Tests for `interactors/work_record_photo_upload_init_interactor.rs`

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::ClockPort;
use crate::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoRow, WorkRecordPhotoStatus,
};
use crate::work_record::ports::WorkRecordPhotoUploadInitOutputPort;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use time::macros::{date, datetime};
use time::{Date, OffsetDateTime};

struct FakeClock {
    today_val: Date,
    now_val: OffsetDateTime,
}

impl ClockPort for FakeClock {
    fn today(&self) -> Date {
        self.today_val
    }

    fn now(&self) -> OffsetDateTime {
        self.now_val
    }
}

struct SpyInitOutput {
    events: Arc<Mutex<Vec<String>>>,
    output: Arc<Mutex<Option<crate::work_record::dtos::WorkRecordPhotoUploadInitOutput>>>,
    errors: Arc<Mutex<Option<BTreeMap<String, Vec<String>>>>>,
}

impl WorkRecordPhotoUploadInitOutputPort for SpyInitOutput {
    fn on_success(
        &mut self,
        output: crate::work_record::dtos::WorkRecordPhotoUploadInitOutput,
    ) {
        self.events.lock().unwrap().push("success".into());
        *self.output.lock().unwrap() = Some(output);
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.events.lock().unwrap().push("record_invalid".into());
        *self.errors.lock().unwrap() = Some(errors);
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
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubPhotoGateway {
    record_exists: bool,
    photo_count: i32,
    next_id: i64,
}

impl WorkRecordPhotoGateway for StubPhotoGateway {
    fn count_for_record(
        &self,
        _: i64,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.photo_count)
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
        plan_id: i64,
        work_record_id: i64,
        storage_key: &str,
        content_type: &str,
        now: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        Ok(WorkRecordPhotoRow {
            id: self.next_id,
            work_record_id,
            cultivation_plan_id: plan_id,
            storage_key: storage_key.into(),
            content_type: Some(content_type.into()),
            byte_size: None,
            position: None,
            status: WorkRecordPhotoStatus::Pending,
            created_at: now,
            updated_at: now,
        })
    }

    fn find_for_record(
        &self,
        _: i64,
        _: i64,
        _: i64,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
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
        Ok(Vec::new())
    }

    fn work_record_exists(
        &self,
        _: i64,
        _: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.record_exists)
    }

    fn delete_stale_pending_older_than(
        &self,
        _: OffsetDateTime,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Vec::new())
    }
}

fn owned_plan(user_id: i64) -> CultivationPlanEntity {
    CultivationPlanEntity {
        id: 1,
        farm_id: 10,
        user_id,
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

#[test]
fn upload_init_rejects_when_photo_limit_exceeded() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let output = Arc::new(Mutex::new(None));
    let errors = Arc::new(Mutex::new(None));
    let mut presenter = SpyInitOutput {
        events: events.clone(),
        output,
        errors: errors.clone(),
    };
    let plan_gateway = StubPlanGateway {
        plan: owned_plan(7),
    };
    let photo_gateway = StubPhotoGateway {
        record_exists: true,
        photo_count: 3,
        next_id: 99,
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 12:00 UTC),
    };
    let upload_url_builder = |_: i64, _: i64, _: i64| "/upload".into();
    let mut interactor = super::WorkRecordPhotoUploadInitInteractor::new(
        &mut presenter,
        &plan_gateway,
        &photo_gateway,
        &clock,
        &upload_url_builder,
    );
    interactor
        .call_rescuing(7, 1, 42, "image/jpeg")
        .expect("call");
    assert_eq!(vec!["record_invalid"], *events.lock().unwrap());
    let errs = errors.lock().unwrap().clone().expect("errors");
    assert!(errs.contains_key("photos"));
}

#[test]
fn upload_init_success_returns_upload_metadata() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let output = Arc::new(Mutex::new(None));
    let errors = Arc::new(Mutex::new(None));
    let mut presenter = SpyInitOutput {
        events: events.clone(),
        output: output.clone(),
        errors,
    };
    let plan_gateway = StubPlanGateway {
        plan: owned_plan(7),
    };
    let photo_gateway = StubPhotoGateway {
        record_exists: true,
        photo_count: 0,
        next_id: 55,
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 12:00 UTC),
    };
    let upload_url_builder =
        |plan: i64, record: i64, photo: i64| format!("/plans/{plan}/records/{record}/photos/{photo}");
    let mut interactor = super::WorkRecordPhotoUploadInitInteractor::new(
        &mut presenter,
        &plan_gateway,
        &photo_gateway,
        &clock,
        &upload_url_builder,
    );
    interactor
        .call_rescuing(7, 1, 42, "image/png")
        .expect("call");
    assert_eq!(vec!["success"], *events.lock().unwrap());
    let out = output.lock().unwrap().clone().expect("output");
    assert_eq!(55, out.photo_id);
    assert_eq!("PUT", out.upload_method);
    assert_eq!("image/png", out.content_type);
    assert!(out.upload_url.contains("/photos/55"));
}
