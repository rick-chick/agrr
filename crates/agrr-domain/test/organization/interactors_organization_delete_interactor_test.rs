// Tests for `interactors/organization_delete_interactor.rs`

use crate::organization::dtos::{OrganizationDeleteFailure, OrganizationRole};
use crate::organization::entities::{OrganizationEntity, OrganizationMembershipEntity};
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::interactors::OrganizationDeleteInteractor;
use crate::organization::ports::OrganizationDeleteOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;
use std::sync::atomic::{AtomicBool, Ordering};

struct DeleteGateways {
    org: OrganizationEntity,
    membership: Option<OrganizationMembershipEntity>,
    deleted: AtomicBool,
}

impl OrganizationGateway for DeleteGateways {
    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.org.clone())
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
        self.deleted.store(true, Ordering::SeqCst);
        Ok(())
    }
}

impl OrganizationMembershipGateway for DeleteGateways {
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
    success: bool,
    failure: Option<OrganizationDeleteFailure>,
}

impl OrganizationDeleteOutputPort for RecordingPort {
    fn on_success(&mut self) {
        self.success = true;
    }

    fn on_failure(&mut self, failure: OrganizationDeleteFailure) {
        self.failure = Some(failure);
    }
}

fn team_org(is_personal: bool) -> OrganizationEntity {
    OrganizationEntity {
        id: 1,
        name: "Team".into(),
        slug: "team".into(),
        is_personal,
        created_at: String::new(),
        updated_at: String::new(),
    }
}

#[test]
fn owner_can_delete_team_org() {
    let gateway = DeleteGateways {
        org: team_org(false),
        membership: Some(OrganizationMembershipEntity {
            id: 1,
            organization_id: 1,
            user_id: 5,
            role: OrganizationRole::Owner,
            created_at: String::new(),
            updated_at: String::new(),
        }),
        deleted: AtomicBool::new(false),
    };
    let user_lookup = StubUserLookup {
        user: User::new(5, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationDeleteInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        1,
    );
    interactor.call().unwrap();
    assert!(port.success);
    assert!(gateway.deleted.load(Ordering::SeqCst));
}

#[test]
fn personal_org_delete_forbidden() {
    let gateway = DeleteGateways {
        org: team_org(true),
        membership: Some(OrganizationMembershipEntity {
            id: 1,
            organization_id: 1,
            user_id: 5,
            role: OrganizationRole::Owner,
            created_at: String::new(),
            updated_at: String::new(),
        }),
        deleted: AtomicBool::new(false),
    };
    let user_lookup = StubUserLookup {
        user: User::new(5, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationDeleteInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        1,
    );
    interactor.call().unwrap();
    assert_eq!(
        port.failure,
        Some(OrganizationDeleteFailure::PersonalOrgForbidden)
    );
}
