// Tests for `interactors/organization_update_interactor.rs`

use crate::organization::dtos::{OrganizationRole, OrganizationUpdateInput};
use crate::organization::entities::{OrganizationEntity, OrganizationMembershipEntity};
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::interactors::OrganizationUpdateInteractor;
use crate::organization::ports::{OrganizationUpdateOutputPort, UpdateFailure};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

struct UpdateGateways {
    org: OrganizationEntity,
    membership: Option<OrganizationMembershipEntity>,
}

impl OrganizationGateway for UpdateGateways {
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
        name: Option<&str>,
        _: Option<&str>,
    ) -> Result<OrganizationEntity, Box<dyn std::error::Error + Send + Sync>> {
        let mut org = self.org.clone();
        if let Some(n) = name {
            org.name = n.to_string();
        }
        Ok(org)
    }

    fn delete(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

impl OrganizationMembershipGateway for UpdateGateways {
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
    failure: Option<UpdateFailure>,
}

impl OrganizationUpdateOutputPort for RecordingPort {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.success = Some(organization);
    }

    fn on_failure(&mut self, failure: UpdateFailure) {
        self.failure = Some(failure);
    }
}

fn base_org() -> OrganizationEntity {
    OrganizationEntity {
        id: 1,
        name: "Old".into(),
        slug: "old".into(),
        is_personal: false,
        created_at: String::new(),
        updated_at: String::new(),
    }
}

#[test]
fn admin_member_can_update() {
    let gateway = UpdateGateways {
        org: base_org(),
        membership: Some(OrganizationMembershipEntity {
            id: 1,
            organization_id: 1,
            user_id: 5,
            role: OrganizationRole::Admin,
            created_at: String::new(),
            updated_at: String::new(),
        }),
    };
    let user_lookup = StubUserLookup {
        user: User::new(5, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor = OrganizationUpdateInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        1,
    );
    interactor
        .call(OrganizationUpdateInput {
            name: Some("New".into()),
            slug: None,
        })
        .unwrap();
    assert_eq!(port.success.as_ref().map(|o| o.name.as_str()), Some("New"));
}

#[test]
fn member_cannot_update() {
    let gateway = UpdateGateways {
        org: base_org(),
        membership: Some(OrganizationMembershipEntity {
            id: 1,
            organization_id: 1,
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
    let mut interactor = OrganizationUpdateInteractor::new(
        &mut port,
        &gateway,
        &gateway,
        &user_lookup,
        5,
        1,
    );
    interactor
        .call(OrganizationUpdateInput {
            name: Some("New".into()),
            slug: None,
        })
        .unwrap();
    assert_eq!(
        port.failure,
        Some(UpdateFailure::Policy(PolicyPermissionDenied))
    );
}
