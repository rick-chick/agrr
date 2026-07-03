// Tests for `interactors/work_record_create_interactor.rs`

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::ClockPort;
use crate::work_record::dtos::{WorkRecordRead, WorkRecordTaskScheduleItemSummary};
use crate::work_record::gateways::{
    TaskScheduleItemLookupGateway, TaskScheduleItemPrefillSnapshot, WorkRecordCreatePersistAttrs,
    WorkRecordGateway,
};
use crate::work_record::ports::WorkRecordCreateOutputPort;
use rust_decimal::Decimal;
use serde_json::Value;
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

struct SpyCreateOutput {
    events: Arc<Mutex<Vec<String>>>,
    record: Arc<Mutex<Option<WorkRecordRead>>>,
    errors: Arc<Mutex<Option<BTreeMap<String, Vec<String>>>>>,
}

impl WorkRecordCreateOutputPort for SpyCreateOutput {
    fn on_success(&mut self, record: WorkRecordRead) {
        self.events.lock().unwrap().push("success".into());
        *self.record.lock().unwrap() = Some(record);
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
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubItemLookup {
    snapshot: Option<TaskScheduleItemPrefillSnapshot>,
}

impl TaskScheduleItemLookupGateway for StubItemLookup {
    fn find_item_for_plan(
        &self,
        _: i64,
        _: i64,
    ) -> Result<
        TaskScheduleItemPrefillSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        self.snapshot
            .clone()
            .ok_or_else(|| Box::new(RecordNotFoundError) as Box<dyn std::error::Error + Send + Sync>)
    }
}

struct StubWorkRecordGateway {
    create_calls: Arc<Mutex<Vec<(i64, WorkRecordCreatePersistAttrs)>>>,
    create_result: WorkRecordRead,
}

impl WorkRecordGateway for StubWorkRecordGateway {
    fn create(
        &self,
        plan_id: i64,
        attrs: WorkRecordCreatePersistAttrs,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        self.create_calls.lock().unwrap().push((plan_id, attrs));
        Ok(self.create_result.clone())
    }

    fn list_for_plan(
        &self,
        _: i64,
        _: &crate::work_record::dtos::WorkRecordListInput,
    ) -> Result<Vec<WorkRecordRead>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_for_plan(
        &self,
        _: i64,
        _: i64,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: i64,
        _: &crate::work_record::dtos::WorkRecordUpdateInput,
        _: OffsetDateTime,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn destroy(
        &self,
        _: i64,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<crate::work_record::gateways::WorkRecordDestroyGatewayOutcome, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

fn private_plan(user_id: i64) -> CultivationPlanEntity {
    CultivationPlanEntity {
        id: 2,
        farm_id: 1,
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

fn sample_read() -> WorkRecordRead {
    WorkRecordRead {
        id: 10,
        cultivation_plan_id: 2,
        field_cultivation_id: Some(45),
        task_schedule_item_id: Some(123),
        agricultural_task_id: Some(7),
        name: "除草".into(),
        task_type: Some("field_work".into()),
        actual_date: date!(2026-06-12),
        amount: Some(Decimal::new(15, 1)),
        amount_unit: Some("kg".into()),
        time_spent_minutes: None,
        notes: Some("雨上がり".into()),
        created_at: datetime!(2026-06-12 10:00 UTC),
        updated_at: datetime!(2026-06-12 10:00 UTC),
        task_schedule_item: Some(WorkRecordTaskScheduleItemSummary {
            id: 123,
            name: "除草".into(),
            scheduled_date: Some(date!(2026-06-10)),
        }),
    }
}

#[test]
fn creates_scheduled_record_with_item_prefill() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let record_slot = Arc::new(Mutex::new(None));
    let mut output = SpyCreateOutput {
        events: Arc::clone(&events),
        record: Arc::clone(&record_slot),
        errors: Arc::new(Mutex::new(None)),
    };
    let create_calls = Arc::new(Mutex::new(Vec::new()));
    let gateway = StubWorkRecordGateway {
        create_calls: Arc::clone(&create_calls),
        create_result: sample_read(),
    };
    let item_lookup = StubItemLookup {
        snapshot: Some(TaskScheduleItemPrefillSnapshot {
            cultivation_plan_id: 2,
            field_cultivation_id: Some(45),
            agricultural_task_id: Some(7),
            name: "除草".into(),
            task_type: Some("field_work".into()),
            scheduled_date: Some(date!(2026-06-10)),
            amount: Some(Decimal::new(15, 1)),
            amount_unit: Some("kg".into()),
        }),
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor = WorkRecordCreateInteractor::new(
        &mut output,
        &plan_gateway,
        &gateway,
        &item_lookup,
        &clock,
    );

    let mut params = BTreeMap::new();
    params.insert(
        "task_schedule_item_id".into(),
        Value::Number(123.into()),
    );
    params.insert(
        "actual_date".into(),
        Value::String("2026-06-12".into()),
    );
    params.insert("notes".into(), Value::String("雨上がり".into()));

    interactor.call_rescuing(1, 2, &params).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
    let calls = create_calls.lock().unwrap();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].0, 2);
    assert_eq!(calls[0].1.name, "除草");
    assert_eq!(calls[0].1.task_type.as_deref(), Some("field_work"));
    assert_eq!(calls[0].1.field_cultivation_id, Some(45));
    assert_eq!(calls[0].1.agricultural_task_id, Some(7));
    assert_eq!(calls[0].1.amount, Some(Decimal::new(15, 1)));
    assert_eq!(calls[0].1.notes.as_deref(), Some("雨上がり"));
    assert!(record_slot.lock().unwrap().is_some());
}

#[test]
fn dispatches_record_invalid_when_item_belongs_to_other_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let errors = Arc::new(Mutex::new(None));
    let mut output = SpyCreateOutput {
        events: Arc::clone(&events),
        record: Arc::new(Mutex::new(None)),
        errors: Arc::clone(&errors),
    };
    let gateway = StubWorkRecordGateway {
        create_calls: Arc::new(Mutex::new(Vec::new())),
        create_result: sample_read(),
    };
    let item_lookup = StubItemLookup {
        snapshot: Some(TaskScheduleItemPrefillSnapshot {
            cultivation_plan_id: 99,
            field_cultivation_id: None,
            agricultural_task_id: None,
            name: "除草".into(),
            task_type: None,
            scheduled_date: None,
            amount: None,
            amount_unit: None,
        }),
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor = WorkRecordCreateInteractor::new(
        &mut output,
        &plan_gateway,
        &gateway,
        &item_lookup,
        &clock,
    );

    let mut params = BTreeMap::new();
    params.insert(
        "task_schedule_item_id".into(),
        Value::Number(123.into()),
    );

    interactor.call_rescuing(1, 2, &params).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["record_invalid".to_string()]);
    assert!(
        errors
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .contains_key("task_schedule_item_id")
    );
}

#[test]
fn dispatches_record_invalid_when_ad_hoc_name_missing() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let errors = Arc::new(Mutex::new(None));
    let mut output = SpyCreateOutput {
        events: Arc::clone(&events),
        record: Arc::new(Mutex::new(None)),
        errors: Arc::clone(&errors),
    };
    let gateway = StubWorkRecordGateway {
        create_calls: Arc::new(Mutex::new(Vec::new())),
        create_result: sample_read(),
    };
    let item_lookup = StubItemLookup { snapshot: None };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor = WorkRecordCreateInteractor::new(
        &mut output,
        &plan_gateway,
        &gateway,
        &item_lookup,
        &clock,
    );

    let mut params = BTreeMap::new();
    params.insert(
        "actual_date".into(),
        Value::String("2026-06-12".into()),
    );

    interactor.call_rescuing(1, 2, &params).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["record_invalid".to_string()]);
    assert!(
        errors
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .contains_key("name")
    );
}

#[test]
fn dispatches_not_found_when_private_plan_access_denied() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyCreateOutput {
        events: Arc::clone(&events),
        record: Arc::new(Mutex::new(None)),
        errors: Arc::new(Mutex::new(None)),
    };
    let create_calls = Arc::new(Mutex::new(Vec::new()));
    let gateway = StubWorkRecordGateway {
        create_calls: Arc::clone(&create_calls),
        create_result: sample_read(),
    };
    let item_lookup = StubItemLookup { snapshot: None };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(99),
    };
    let mut interactor = WorkRecordCreateInteractor::new(
        &mut output,
        &plan_gateway,
        &gateway,
        &item_lookup,
        &clock,
    );

    interactor.call_rescuing(1, 2, &BTreeMap::new()).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
    assert!(create_calls.lock().unwrap().is_empty());
}
