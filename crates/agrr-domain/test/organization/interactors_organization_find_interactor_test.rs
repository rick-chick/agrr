// Tests for `interactors/organization_find_interactor.rs`

use crate::organization::dtos::{OrganizationFindFailure, OrganizationRole};
use crate::organization::entities::{OrganizationEntity, OrganizationMembershipEntity};
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::interactors::OrganizationFindInteractor;
use crate::organization::ports::OrganizationFindOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

struct StubGateways {
    org: Option<OrganizationEntity>,
    membership: Option<OrganizationMembershipEntity>,
}

impl OrganizationGateway for StubGateways {
    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.org
            .clone()
            .ok_or_else(|| Box::new(crate::shared::exceptions::RecordNotFoundError) as _)
    }

    fn find_by_slug(
        &self,
        _: &str,
    ) -> Result<Option<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_for_user(
        &self,
        _: i64,
    ) -> Result<Vec<OrganizationEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create(
        &self,
        _: &str,
        _: &str,
        _: bool,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        _: Option<&str>,
        _: Option<&str>,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

impl OrganizationMembershipGateway for StubGateways {
    fn find_membership(
        &self,
        _: i64,
        _: i64,
    ) -> Result<Option<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(self.membership.clone())
    }

    fn list_for_organization(
        &self,
        _: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_for_user(
        &self,
        _: i64,
    ) -> Result<Vec<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create(
        &self,
        _: i64,
        _: i64,
        _: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_role(
        &self,
        _: i64,
        _: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct StubUserLookup {
    user: User,
}

impl UserLookupGateway for StubUserLookup {
    fn find(&self, _: i64) -> User {
        self.user
    }
}

#[derive(Default)]
struct RecordingPort {
    success: Option<OrganizationEntity>,
    failure: Option<OrganizationFindFailure>,
}

impl OrganizationFindOutputPort for RecordingPort {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.success = Some(organization);
    }

    fn on_failure(&mut self, failure: OrganizationFindFailure) {
        self.failure = Some(failure);
    }
}

fn sample_org() -> OrganizationEntity {
    OrganizationEntity {
        id: 10,
        name: "Team".into(),
        slug: "team".into(),
        is_personal: false,
        created_at: String::new(),
        updated_at: String::new(),
    }
}

#[test]
fn find_succeeds_for_member() {
    let gateway = StubGateways {
        org: Some(sample_org()),
        membership: Some(OrganizationMembershipEntity {
            id: 1,
            organization_id: 10,
            user_id: 5,
            role: OrganizationRole::Member,
            created_at: String::new(),
            updated_at: String::new(),
        }),
    };
    let user_lookup = StubUserLookup {
        user: User::new(5, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationFindInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        10,
    );
    interactor.call().unwrap();
    assert!(port.success.is_some());
}

#[test]
fn find_denied_without_membership() {
    let gateway = StubGateways {
        org: Some(sample_org()),
        membership: None,
    };
    let user_lookup = StubUserLookup {
        user: User::new(5, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationFindInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        10,
    );
    interactor.call().unwrap();
    assert_eq!(
        port.failure,
        Some(OrganizationFindFailure::Policy(PolicyPermissionDenied))
    );
}
