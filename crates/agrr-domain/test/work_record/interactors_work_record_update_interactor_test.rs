// Tests for `interactors/work_record_update_interactor.rs`

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::ports::ClockPort;
use crate::work_record::dtos::{WorkRecordClimateSnapshot, WorkRecordListInput, WorkRecordRead};
use crate::work_record::gateways::{
    WorkRecordClimatePersistFields, WorkRecordClimateSnapshotGateway,
    WorkRecordCreatePersistAttrs, WorkRecordGateway,
};
use rust_decimal::Decimal;
use crate::work_record::ports::WorkRecordUpdateOutputPort;
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use time::macros::{date, datetime};
use time::{Date, OffsetDateTime};


    struct EmptyScopeGateway;
    impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
        fn organization_ids_for_user(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }
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

struct SpyUpdateOutput {
    events: Arc<Mutex<Vec<String>>>,
    errors: Arc<Mutex<Option<BTreeMap<String, Vec<String>>>>>,
}

impl WorkRecordUpdateOutputPort for SpyUpdateOutput {
    fn on_success(&mut self, _: WorkRecordRead) {
        self.events.lock().unwrap().push("success".into());
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

    fn on_stale_update(&mut self) {
        self.events.lock().unwrap().push("stale".into());
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

struct EmptyClimateSnapshot;

impl WorkRecordClimateSnapshotGateway for EmptyClimateSnapshot {
    fn lookup(
        &self,
        _: i64,
        _: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Ok(WorkRecordClimateSnapshot::empty())
    }
}

struct FailingClimateSnapshot;

impl WorkRecordClimateSnapshotGateway for FailingClimateSnapshot {
    fn lookup(
        &self,
        _: i64,
        _: Date,
    ) -> Result<WorkRecordClimateSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Err("climate_progress_unavailable".into())
    }
}

struct RecordingUpdateGateway {
    existing: WorkRecordRead,
    climate_at_update: Arc<Mutex<Option<Option<WorkRecordClimatePersistFields>>>>,
}

impl WorkRecordGateway for RecordingUpdateGateway {
    fn create(
        &self,
        _: i64,
        _: WorkRecordCreatePersistAttrs,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_for_plan(
        &self,
        _: i64,
        _: &WorkRecordListInput,
    ) -> Result<Vec<WorkRecordRead>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_for_plan(
        &self,
        _: i64,
        _: i64,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.existing.clone())
    }

    fn update(
        &self,
        _: i64,
        _: i64,
        _: &crate::work_record::dtos::WorkRecordUpdateInput,
        climate: Option<&WorkRecordClimatePersistFields>,
        _: OffsetDateTime,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        *self.climate_at_update.lock().unwrap() = Some(climate.map(|c| WorkRecordClimatePersistFields {
            gdd_at_actual: c.gdd_at_actual,
            weather_snapshot: c.weather_snapshot.clone(),
        }));
        Ok(self.existing.clone())
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

struct StubWorkRecordGateway;

impl WorkRecordGateway for StubWorkRecordGateway {
    fn create(
        &self,
        _: i64,
        _: WorkRecordCreatePersistAttrs,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_for_plan(
        &self,
        _: i64,
        _: &WorkRecordListInput,
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
        _: Option<&crate::work_record::gateways::WorkRecordClimatePersistFields>,
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

#[test]
fn dispatches_record_invalid_when_task_schedule_item_id_is_submitted() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let errors = Arc::new(Mutex::new(None));
    let mut output = SpyUpdateOutput {
        events: Arc::clone(&events),
        errors: Arc::clone(&errors),
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor = WorkRecordUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &StubWorkRecordGateway,
        &EmptyClimateSnapshot,
        &clock,
        &EmptyScopeGateway,
    );

    let mut params = BTreeMap::new();
    params.insert(
        "task_schedule_item_id".into(),
        Value::Number(123.into()),
    );

    interactor.call_rescuing(1, 2, 10, &params).unwrap();

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
fn dispatches_not_found_when_private_plan_access_denied() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyUpdateOutput {
        events: Arc::clone(&events), errors: Arc::new(Mutex::new(None)),
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(99),
    };
    let mut interactor = WorkRecordUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &StubWorkRecordGateway,
        &EmptyClimateSnapshot,
        &clock,
        &EmptyScopeGateway,
    );

    interactor
        .call_rescuing(1, 2, 10, &BTreeMap::new())
        .unwrap();

    assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
}

fn sample_existing_work_record() -> WorkRecordRead {
    WorkRecordRead {
        id: 10,
        cultivation_plan_id: 2,
        field_cultivation_id: Some(45),
        task_schedule_item_id: Some(123),
        agricultural_task_id: Some(7),
        fertilize_id: None,
        pesticide_id: None,
        name: "除草".into(),
        task_type: Some("field_work".into()),
        actual_date: date!(2026-06-10),
        amount: Some(Decimal::new(15, 1)),
        amount_unit: Some("kg".into()),
        time_spent_minutes: None,
        notes: Some("雨上がり".into()),
        gdd_at_actual: Some(99.0),
        weather_snapshot: Some(serde_json::json!({ "date": "2026-06-10" })),
        created_at: datetime!(2026-06-10 10:00 UTC),
        updated_at: datetime!(2026-06-10 10:00 UTC),
        field_name: Some("F1".into()),
        crop_name: Some("トマト".into()),
        task_schedule_item: None,
    }
}

#[test]
fn update_omits_climate_refresh_when_snapshot_lookup_fails() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyUpdateOutput {
        events: Arc::clone(&events),
        errors: Arc::new(Mutex::new(None)),
    };
    let clock = FakeClock {
        today_val: date!(2026-06-12),
        now_val: datetime!(2026-06-12 10:00 UTC),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let climate_slot = Arc::new(Mutex::new(None));
    let gateway = RecordingUpdateGateway {
        existing: sample_existing_work_record(),
        climate_at_update: Arc::clone(&climate_slot),
    };
    let mut interactor = WorkRecordUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &gateway,
        &FailingClimateSnapshot,
        &clock,
        &EmptyScopeGateway,
    );

    let mut params = BTreeMap::new();
    params.insert(
        "actual_date".into(),
        Value::String("2026-06-12".into()),
    );
    params.insert(
        "updated_at".into(),
        Value::String("2026-06-10T10:00:00Z".into()),
    );

    interactor.call_rescuing(1, 2, 10, &params).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
    assert_eq!(climate_slot.lock().unwrap().as_ref(), Some(&None));
}
