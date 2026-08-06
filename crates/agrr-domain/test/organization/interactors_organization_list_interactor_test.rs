// Tests for `interactors/organization_list_interactor.rs`

use crate::organization::entities::OrganizationEntity;
use crate::organization::gateways::OrganizationGateway;
use crate::organization::interactors::OrganizationListInteractor;
use crate::organization::ports::OrganizationListOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;

struct StubOrgGateway {
    orgs: Vec<OrganizationEntity>,
}

impl OrganizationGateway for StubOrgGateway {
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
        Ok(self.orgs.clone())
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
    success: Option<Vec<OrganizationEntity>>,
}

impl OrganizationListOutputPort for RecordingPort {
    fn on_success(&mut self, organizations: Vec<OrganizationEntity>) {
        self.success = Some(organizations);
    }

    fn on_failure(&mut self, _: crate::organization::dtos::OrganizationListFailure) {
        panic!("unexpected failure");
    }
}

#[test]
fn lists_organizations_for_user() {
    let org = OrganizationEntity {
        id: 1,
        name: "Team".into(),
        slug: "team".into(),
        is_personal: false,
        created_at: String::new(),
        updated_at: String::new(),
    };
    let gateway = StubOrgGateway {
        orgs: vec![org.clone()],
    };
    let user_lookup = StubUserLookup {
        user: User::new(7, false),
    };
    let mut port = RecordingPort::default();
    let mut interactor =
        OrganizationListInteractor::new(&mut port, &gateway, &user_lookup, 7);
    interactor.call().unwrap();
    assert_eq!(port.success, Some(vec![org]));
}
