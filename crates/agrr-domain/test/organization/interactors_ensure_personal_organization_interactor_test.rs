// Tests for `interactors/ensure_personal_organization_interactor.rs`

use crate::organization::gateways::{PersonalOrganizationGateway, PersonalOrganizationUserRow};
use crate::organization::interactors::EnsurePersonalOrganizationInteractor;
use std::sync::Mutex;

struct RecordingPersonalOrgGateway {
    calls: Mutex<Vec<(i64, String, String)>>,
    org_id: i64,
}

impl RecordingPersonalOrgGateway {
    fn new(org_id: i64) -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
            org_id,
        }
    }
}

impl PersonalOrganizationGateway for RecordingPersonalOrgGateway {
    fn ensure_personal_organization(
        &self,
        user_id: i64,
        email: &str,
        name: &str,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.calls.lock().unwrap().push((
            user_id,
            email.to_string(),
            name.to_string(),
        ));
        Ok(self.org_id)
    }

    fn list_users_needing_personal_organization(
        &self,
    ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

#[test]
fn ensure_personal_organization_delegates_to_gateway() {
    let gateway = RecordingPersonalOrgGateway::new(99);
    let interactor = EnsurePersonalOrganizationInteractor::new(&gateway);
    let org_id = interactor
        .call(7, "u@example.com", "User")
        .expect("ensure personal org");
    assert_eq!(99, org_id);
    let calls = gateway.calls.lock().unwrap();
    assert_eq!(1, calls.len());
    assert_eq!((7, "u@example.com".into(), "User".into()), calls[0].clone());
}
