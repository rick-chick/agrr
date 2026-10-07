// Tests for `interactors/weather_reschedule_proposals_list_interactor.rs`.

use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleProposalContext;
use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, WeatherRescheduleProposalReadGateway,
};
use crate::cultivation_plan::interactors::WeatherRescheduleProposalsListInteractor;
use crate::cultivation_plan::ports::WeatherRescheduleProposalsListOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;
use std::sync::{Arc, Mutex};

struct SpyOutput {
    events: Arc<Mutex<Vec<String>>>,
}
impl WeatherRescheduleProposalsListOutputPort for SpyOutput {
    fn on_success(&mut self, _: Vec<crate::cultivation_plan::dtos::WeatherRescheduleProposalRead>) {
        self.events.lock().unwrap().push("success".into());
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

struct StubReadGateway {
    calls: Arc<Mutex<u32>>,
}
impl WeatherRescheduleProposalReadGateway for StubReadGateway {
    fn find_context_by_plan_id(
        &self,
        _: i64,
    ) -> Result<WeatherRescheduleProposalContext, Box<dyn std::error::Error + Send + Sync>> {
        *self.calls.lock().unwrap() += 1;
        unimplemented!()
    }
}

include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/test/cultivation_plan/member_scope_test_fixtures.inc.rs"
));

#[test]
fn returns_not_found_when_org_member_lists_other_users_proposals() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let read_calls = Arc::new(Mutex::new(0));
    let read_gateway = StubReadGateway {
        calls: Arc::clone(&read_calls),
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
    let mut interactor = WeatherRescheduleProposalsListInteractor::new(
        &mut output,
        99,
        2,
        &plan_gateway,
        &read_gateway,
        &user_lookup,
        &scope,
    );

    let err = interactor.call().unwrap_err();
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
    assert_eq!(0, *read_calls.lock().unwrap());
    assert!(events.lock().unwrap().is_empty());
}
