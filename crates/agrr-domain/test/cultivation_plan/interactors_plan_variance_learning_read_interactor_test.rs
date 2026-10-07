// Tests for `interactors/plan_variance_learning_read_interactor.rs`.

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::dtos::PlanVarianceLearningSnapshotRead;
use crate::cultivation_plan::interactors::PlanVarianceLearningReadInteractor;
use crate::cultivation_plan::ports::PlanVarianceLearningReadOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use std::collections::BTreeMap;
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
impl PlanVarianceLearningReadOutputPort for SpyOutput {
    fn on_success(&mut self, _: crate::cultivation_plan::dtos::PlanVarianceLearningSnapshotRead) {
        self.events.lock().unwrap().push("success".into());
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

struct SpyVarianceLearningGateway {
    progress_reads: Arc<Mutex<u32>>,
}
impl PlanVarianceLearningGateway for SpyVarianceLearningGateway {
    fn save(
        &self,
        _: i64,
        _: i64,
        _: &crate::cultivation_plan::dtos::PlanVsActualSummaryRead,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_by_plan_id(
        &self,
        _: i64,
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_proposal_application_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>> {
        *self.progress_reads.lock().unwrap() += 1;
        unimplemented!()
    }
    fn upsert_proposal_application_progress(
        &self,
        _: i64,
        _: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_reorganize_orchestration_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
    fn upsert_reorganize_orchestration_progress(
        &self,
        _: i64,
        _: &crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressPatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn find_learn_handoff_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::LearnHandoffStateRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }
    fn patch_learn_handoff(
        &self,
        _: i64,
        _: &crate::cultivation_plan::dtos::LearnHandoffStatePatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/test/cultivation_plan/member_scope_test_fixtures.inc.rs"
));

#[test]
fn returns_not_found_when_org_member_reads_other_users_variance_learning() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let variance_calls = Arc::new(Mutex::new(0));
    let variance_gateway = SpyVarianceLearningGateway {
        progress_reads: Arc::clone(&variance_calls),
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
    let mut interactor = PlanVarianceLearningReadInteractor::new(
        &mut output,
        99,
        2,
        &plan_gateway,
        &variance_gateway,
        &FakeTranslator,
        &FakeLogger,
        &user_lookup,
        &scope,
    );

    let err = interactor.call().unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
    assert_eq!(0, *variance_calls.lock().unwrap());
    assert!(events.lock().unwrap().is_empty());
}
