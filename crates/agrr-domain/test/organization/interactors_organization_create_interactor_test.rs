// Tests for `interactors/organization_create_interactor.rs`

use crate::organization::dtos::OrganizationCreateInput;
use crate::organization::dtos::OrganizationRole;
use crate::organization::entities::{OrganizationEntity, OrganizationMembershipEntity};
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::interactors::OrganizationCreateInteractor;
use crate::organization::ports::{CreateFailure, OrganizationCreateOutputPort};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;
use std::sync::Mutex;

struct RecordingGateways {
    created_org: Mutex<Option<OrganizationEntity>>,
    membership_calls: Mutex<Vec<(i64, i64, OrganizationRole)>>,
}

impl RecordingGateways {
    fn new() -> Self {
        Self {
            created_org: Mutex::new(None),
            membership_calls: Mutex::new(Vec::new()),
        }
    }
}

impl OrganizationGateway for RecordingGateways {
    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
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
        name: &str,
        slug: &str,
        is_personal: bool,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        let org = OrganizationEntity {
            id: 42,
            name: name.to_string(),
            slug: slug.to_string(),
            is_personal,
            created_at: String::new(),
            updated_at: String::new(),
        };
        *self.created_org.lock().unwrap() = Some(org.clone());
        Ok(org)
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

impl OrganizationMembershipGateway for RecordingGateways {
    fn find_membership(
        &self,
        _: i64,
        _: i64,
    ) -> Result<Option<OrganizationMembershipEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
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
        organization_id: i64,
        user_id: i64,
        role: OrganizationRole,
    ) -> Result<OrganizationMembershipEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.membership_calls
            .lock()
            .unwrap()
            .push((organization_id, user_id, role));
        Ok(OrganizationMembershipEntity {
            id: 1,
            organization_id,
            user_id,
            role,
            created_at: String::new(),
            updated_at: String::new(),
        })
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
    failure: Option<CreateFailure>,
}

impl OrganizationCreateOutputPort for RecordingPort {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.success = Some(organization);
    }

    fn on_failure(&mut self, failure: CreateFailure) {
        self.failure = Some(failure);
    }
}

#[test]
fn create_org_and_owner_membership() {
    let gateway = RecordingGateways::new();
    let user_lookup = StubUserLookup {
        user: User::new(9, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationCreateInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        9,
    );
    interactor
        .call(OrganizationCreateInput {
            name: "Acme".into(),
            slug: "acme".into(),
        })
        .unwrap();
    assert_eq!(port.success.as_ref().map(|o| o.slug.as_str()), Some("acme"));
    let calls = gateway.membership_calls.lock().unwrap();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0], (42, 9, OrganizationRole::Owner));
}

#[test]
fn rejects_blank_name() {
    let gateway = RecordingGateways::new();
    let user_lookup = StubUserLookup {
        user: User::new(9, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationCreateInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        9,
    );
    interactor
        .call(OrganizationCreateInput {
            name: "  ".into(),
            slug: "acme".into(),
        })
        .unwrap();
    assert!(port.failure.is_some());
}
