// Tests for `interactors/personal_organization_backfill_interactor.rs`

use crate::organization::gateways::{PersonalOrganizationGateway, PersonalOrganizationUserRow};
use crate::organization::interactors::PersonalOrganizationBackfillInteractor;
use std::sync::Mutex;

struct BackfillRecordingGateway {
    users: Vec<PersonalOrganizationUserRow>,
    ensured: Mutex<Vec<i64>>,
}

impl BackfillRecordingGateway {
    fn new(users: Vec<PersonalOrganizationUserRow>) -> Self {
        Self {
            users,
            ensured: Mutex::new(Vec::new()),
        }
    }
}

impl PersonalOrganizationGateway for BackfillRecordingGateway {
    fn ensure_personal_organization(
        &self,
        user_id: i64,
        _email: &str,
        _name: &str,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.ensured.lock().unwrap().push(user_id);
        Ok(user_id)
    }

    fn list_users_needing_personal_organization(
        &self,
    ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.users.clone())
    }
}

#[test]
fn backfill_ensures_each_listed_user() {
    let gateway = BackfillRecordingGateway::new(vec![
        PersonalOrganizationUserRow {
            user_id: 1,
            email: "a@example.com".into(),
            name: "A".into(),
        },
        PersonalOrganizationUserRow {
            user_id: 2,
            email: "b@example.com".into(),
            name: "B".into(),
        },
    ]);
    let interactor = PersonalOrganizationBackfillInteractor::new(&gateway);
    let processed = interactor.call().expect("backfill");
    assert_eq!(2, processed);
    assert_eq!(vec![1, 2], *gateway.ensured.lock().unwrap());
}

#[test]
fn backfill_no_users_returns_zero() {
    let gateway = BackfillRecordingGateway::new(vec![]);
    let interactor = PersonalOrganizationBackfillInteractor::new(&gateway);
    assert_eq!(0, interactor.call().expect("backfill"));
}
