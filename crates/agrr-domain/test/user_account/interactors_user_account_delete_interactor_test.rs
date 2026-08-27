// Tests for `interactors/user_account_delete_interactor.rs`

use std::sync::Mutex;

use crate::auth::gateways::UserSessionRevocationGateway;
use crate::user_account::dtos::UserAccountDeleteInput;
use crate::user_account::gateways::UserAccountGateway;
use crate::user_account::interactors::UserAccountDeleteInteractor;
use crate::user_account::ports::UserAccountDeleteOutputPort;
use crate::work_record::gateways::WorkRecordPhotoObjectStoreGateway;

struct FakeRevocationGateway {
    deleted_user_ids: Mutex<Vec<i64>>,
}

impl UserSessionRevocationGateway for FakeRevocationGateway {
    fn delete_all_sessions_for_user(&self, user_id: i64) {
        self.deleted_user_ids.lock().unwrap().push(user_id);
    }
}

struct FakeObjectStore {
    deleted_keys: Mutex<Vec<String>>,
}

impl WorkRecordPhotoObjectStoreGateway for FakeObjectStore {
    fn write_object(
        &self,
        _: &str,
        _: &str,
        _: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn read_object(
        &self,
        _: &str,
    ) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_object(
        &self,
        storage_key: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.deleted_keys.lock().unwrap().push(storage_key.to_string());
        Ok(())
    }
}

struct StubAccountGateway {
    photo_keys: Vec<String>,
    email: Option<String>,
    delete_calls: Mutex<Vec<i64>>,
    delete_error: Option<String>,
}

impl UserAccountGateway for StubAccountGateway {
    fn export_data(
        &self,
        _: i64,
    ) -> Result<crate::user_account::dtos::UserDataExport, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn list_photo_storage_keys(
        &self,
        _: i64,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.photo_keys.clone())
    }

    fn delete_account(
        &self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.delete_calls.lock().unwrap().push(user_id);
        if let Some(msg) = &self.delete_error {
            return Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                msg.clone(),
            )));
        }
        Ok(())
    }

    fn user_email(
        &self,
        _: i64,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.email.clone())
    }
}

#[derive(Default)]
struct RecordingPort {
    success: usize,
    not_confirmed: usize,
    failure_message: Option<String>,
}

impl UserAccountDeleteOutputPort for RecordingPort {
    fn on_success(&mut self) {
        self.success += 1;
    }

    fn on_not_confirmed(&mut self) {
        self.not_confirmed += 1;
    }

    fn on_failure(&mut self, message: String) {
        self.failure_message = Some(message);
    }
}

fn run_delete(
    confirm: bool,
    email_confirm: Option<&str>,
    gateway: StubAccountGateway,
) -> (
    RecordingPort,
    Vec<i64>,
    Vec<String>,
    Vec<i64>,
) {
    let revocation = FakeRevocationGateway {
        deleted_user_ids: Mutex::new(vec![]),
    };
    let object_store = FakeObjectStore {
        deleted_keys: Mutex::new(vec![]),
    };
    let mut port = RecordingPort::default();
    let mut interactor = UserAccountDeleteInteractor::new(
        &mut port,
        &gateway,
        &revocation,
        &object_store,
    );
    let input = UserAccountDeleteInput {
        user_id: 42,
        confirm,
        email_confirm: email_confirm.map(str::to_string),
    };
    interactor.call(input).unwrap();
    let sessions = revocation.deleted_user_ids.lock().unwrap().clone();
    let photos = object_store.deleted_keys.lock().unwrap().clone();
    let deletes = gateway.delete_calls.lock().unwrap().clone();
    (port, sessions, photos, deletes)
}

#[test]
fn rejects_when_confirm_is_false() {
    let gateway = StubAccountGateway {
        photo_keys: vec![],
        email: Some("user@example.com".into()),
        delete_calls: Mutex::new(vec![]),
        delete_error: None,
    };
    let (port, sessions, photos, deletes) = run_delete(false, None, gateway);
    assert_eq!(port.not_confirmed, 1);
    assert_eq!(port.success, 0);
    assert!(port.failure_message.is_none());
    assert!(sessions.is_empty());
    assert!(photos.is_empty());
    assert!(deletes.is_empty());
}

#[test]
fn rejects_when_email_confirm_does_not_match() {
    let gateway = StubAccountGateway {
        photo_keys: vec![],
        email: Some("user@example.com".into()),
        delete_calls: Mutex::new(vec![]),
        delete_error: None,
    };
    let (port, sessions, photos, deletes) =
        run_delete(true, Some("wrong@example.com"), gateway);
    assert_eq!(port.failure_message.as_deref(), Some("Email confirmation does not match"));
    assert_eq!(port.success, 0);
    assert!(sessions.is_empty());
    assert!(photos.is_empty());
    assert!(deletes.is_empty());
}

#[test]
fn deletes_account_when_confirmed() {
    let gateway = StubAccountGateway {
        photo_keys: vec![
            "photos/u42/p1.jpg".into(),
            "photos/u42/p2.jpg".into(),
        ],
        email: Some("user@example.com".into()),
        delete_calls: Mutex::new(vec![]),
        delete_error: None,
    };
    let (port, sessions, photos, deletes) =
        run_delete(true, Some("user@example.com"), gateway);
    assert_eq!(port.success, 1);
    assert_eq!(port.not_confirmed, 0);
    assert!(port.failure_message.is_none());
    assert_eq!(sessions, vec![42]);
    assert_eq!(
        photos,
        vec![
            "photos/u42/p1.jpg".to_string(),
            "photos/u42/p2.jpg".to_string()
        ]
    );
    assert_eq!(deletes, vec![42]);
}

#[test]
fn rejects_when_email_confirm_missing_for_user_with_email() {
    let gateway = StubAccountGateway {
        photo_keys: vec![],
        email: Some("user@example.com".into()),
        delete_calls: Mutex::new(vec![]),
        delete_error: None,
    };
    let (port, sessions, photos, deletes) = run_delete(true, None, gateway);
    assert_eq!(
        port.failure_message.as_deref(),
        Some("Email confirmation required")
    );
    assert_eq!(port.success, 0);
    assert!(sessions.is_empty());
    assert!(photos.is_empty());
    assert!(deletes.is_empty());
}

#[test]
fn deletes_account_without_email_confirm_when_user_has_no_email() {
    let gateway = StubAccountGateway {
        photo_keys: vec![],
        email: None,
        delete_calls: Mutex::new(vec![]),
        delete_error: None,
    };
    let (port, sessions, _, deletes) = run_delete(true, None, gateway);
    assert_eq!(port.success, 1);
    assert_eq!(sessions, vec![42]);
    assert_eq!(deletes, vec![42]);
}

#[test]
fn emits_failure_when_delete_account_errors() {
    let gateway = StubAccountGateway {
        photo_keys: vec![],
        email: None,
        delete_calls: Mutex::new(vec![]),
        delete_error: Some("db error".into()),
    };
    let (port, sessions, _, _) = run_delete(true, None, gateway);
    assert_eq!(port.failure_message.as_deref(), Some("db error"));
    assert_eq!(port.success, 0);
    assert_eq!(sessions, vec![42]);
}
