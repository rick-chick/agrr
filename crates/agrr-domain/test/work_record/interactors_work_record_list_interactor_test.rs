// Tests for `interactors/work_record_list_interactor.rs`

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::work_record::dtos::{WorkRecordListInput, WorkRecordRead};
use crate::work_record::gateways::{WorkRecordCreatePersistAttrs, WorkRecordGateway};
use crate::work_record::ports::WorkRecordListOutputPort;
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use time::macros::date;
use time::OffsetDateTime;

struct SpyListOutput {
    events: Arc<Mutex<Vec<String>>>,
    records: Arc<Mutex<Option<Vec<WorkRecordRead>>>>,
    errors: Arc<Mutex<Option<BTreeMap<String, Vec<String>>>>>,
}

impl WorkRecordListOutputPort for SpyListOutput {
    fn on_success(&mut self, records: Vec<WorkRecordRead>) {
        self.events.lock().unwrap().push("success".into());
        *self.records.lock().unwrap() = Some(records);
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

struct StubWorkRecordGateway {
    list_calls: Arc<Mutex<Vec<(i64, WorkRecordListInput)>>>,
    list_result: Vec<WorkRecordRead>,
}

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
        plan_id: i64,
        filter: &WorkRecordListInput,
    ) -> Result<Vec<WorkRecordRead>, Box<dyn std::error::Error + Send + Sync>> {
        self.list_calls
            .lock()
            .unwrap()
            .push((plan_id, filter.clone()));
        Ok(self.list_result.clone())
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
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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

#[test]
fn lists_records_with_date_range_filter() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let records_slot = Arc::new(Mutex::new(None));
    let mut output = SpyListOutput {
        events: Arc::clone(&events),
        records: Arc::clone(&records_slot),
        errors: Arc::new(Mutex::new(None)),
    };
    let list_calls = Arc::new(Mutex::new(Vec::new()));
    let gateway = StubWorkRecordGateway {
        list_calls: Arc::clone(&list_calls),
        list_result: vec![],
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor =
        WorkRecordListInteractor::new(&mut output, &plan_gateway, &gateway);

    let mut query = BTreeMap::new();
    query.insert("from".into(), "2026-06-01".into());
    query.insert("to".into(), "2026-06-30".into());
    query.insert("field_cultivation_id".into(), "45".into());

    interactor.call_rescuing(1, 2, &query).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
    let calls = list_calls.lock().unwrap();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].0, 2);
    assert_eq!(calls[0].1.from, Some(date!(2026-06-01)));
    assert_eq!(calls[0].1.to, Some(date!(2026-06-30)));
    assert_eq!(calls[0].1.field_cultivation_id, Some(45));
    assert!(records_slot.lock().unwrap().is_some());
}

#[test]
fn dispatches_not_found_when_private_plan_access_denied() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyListOutput {
        events: Arc::clone(&events),
        records: Arc::new(Mutex::new(None)),
        errors: Arc::new(Mutex::new(None)),
    };
    let list_calls = Arc::new(Mutex::new(Vec::new()));
    let gateway = StubWorkRecordGateway {
        list_calls: Arc::clone(&list_calls),
        list_result: vec![],
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(99),
    };
    let mut interactor =
        WorkRecordListInteractor::new(&mut output, &plan_gateway, &gateway);

    interactor.call_rescuing(1, 2, &BTreeMap::new()).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
    assert!(list_calls.lock().unwrap().is_empty());
}
