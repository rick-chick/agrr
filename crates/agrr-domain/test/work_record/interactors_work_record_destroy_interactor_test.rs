// Tests for `interactors/work_record_destroy_interactor.rs`

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::RecordNotFoundError;
use crate::work_record::dtos::{WorkRecordListInput, WorkRecordRead};
use crate::work_record::gateways::{WorkRecordCreatePersistAttrs, WorkRecordGateway};
use crate::work_record::ports::WorkRecordDestroyOutputPort;
use serde_json::Value;
use std::sync::{Arc, Mutex};
use time::OffsetDateTime;

struct SpyDestroyOutput {
    events: Arc<Mutex<Vec<String>>>,
}

impl WorkRecordDestroyOutputPort for SpyDestroyOutput {
    fn on_success(&mut self) {
        self.events.lock().unwrap().push("success".into());
    }

    fn on_record_invalid(
        &mut self,
        _: std::collections::BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
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

enum DestroyOutcome {
    Ok,
    NotFound,
}

struct StubWorkRecordGateway {
    destroy_outcome: DestroyOutcome,
    destroy_calls: Arc<Mutex<Vec<(i64, i64)>>>,
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
        _: OffsetDateTime,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn destroy(
        &self,
        plan_id: i64,
        record_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.destroy_calls.lock().unwrap().push((plan_id, record_id));
        match self.destroy_outcome {
            DestroyOutcome::Ok => Ok(()),
            DestroyOutcome::NotFound => Err(Box::new(RecordNotFoundError)),
        }
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
fn destroys_record_after_private_plan_access_check() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyDestroyOutput {
        events: Arc::clone(&events),
    };
    let destroy_calls = Arc::new(Mutex::new(Vec::new()));
    let gateway = StubWorkRecordGateway {
        destroy_outcome: DestroyOutcome::Ok,
        destroy_calls: Arc::clone(&destroy_calls),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor =
        WorkRecordDestroyInteractor::new(&mut output, &plan_gateway, &gateway);

    interactor.call_rescuing(1, 2, 10).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
    assert_eq!(&*destroy_calls.lock().unwrap(), &[(2, 10)]);
}

#[test]
fn dispatches_not_found_when_record_missing() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyDestroyOutput {
        events: Arc::clone(&events),
    };
    let gateway = StubWorkRecordGateway {
        destroy_outcome: DestroyOutcome::NotFound,
        destroy_calls: Arc::new(Mutex::new(Vec::new())),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(1),
    };
    let mut interactor =
        WorkRecordDestroyInteractor::new(&mut output, &plan_gateway, &gateway);

    interactor.call_rescuing(1, 2, 10).unwrap();

    assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
}
