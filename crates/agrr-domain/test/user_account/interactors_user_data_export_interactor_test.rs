// Tests for `interactors/user_data_export_interactor.rs`

use crate::user_account::dtos::{
    UserDataExport, UserDataExportFailure, UserExportSnapshot,
};
use crate::user_account::gateways::UserAccountGateway;
use crate::user_account::interactors::UserDataExportInteractor;
use crate::user_account::ports::UserDataExportOutputPort;

struct StubGateway {
    result: Result<UserDataExport, String>,
}

impl UserAccountGateway for StubGateway {
    fn export_data(
        &self,
        _user_id: i64,
    ) -> Result<UserDataExport, Box<dyn std::error::Error + Send + Sync>> {
        self.result
            .clone()
            .map_err(|e| Box::new(std::io::Error::new(std::io::ErrorKind::Other, e)) as _)
    }

    fn list_photo_storage_keys(
        &self,
        _user_id: i64,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_account(
        &self,
        _user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn user_email(
        &self,
        _user_id: i64,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

#[derive(Default)]
struct RecordingPort {
    success: Option<UserDataExport>,
    failure: Option<UserDataExportFailure>,
}

impl UserDataExportOutputPort for RecordingPort {
    fn on_success(&mut self, export: UserDataExport) {
        self.success = Some(export);
    }

    fn on_failure(&mut self, failure: UserDataExportFailure) {
        self.failure = Some(failure);
    }
}

fn sample_export() -> UserDataExport {
    UserDataExport {
        exported_at: String::new(),
        user: UserExportSnapshot {
            id: 1,
            email: Some("user@example.com".into()),
            name: Some("Test User".into()),
            created_at: Some("2024-01-01T00:00:00Z".into()),
        },
        farms: vec![serde_json::json!({
            "id": 10,
            "name": "Farm A",
            "latitude": 35.0,
            "longitude": 139.0,
            "is_reference": false
        })],
        crops: vec![serde_json::json!({
            "id": 20,
            "name": "Tomato",
            "variety": "Cherry",
            "is_reference": false
        })],
        cultivation_plans: vec![serde_json::json!({
            "id": 30,
            "plan_name": "Plan 2025",
            "plan_year": 2025,
            "plan_type": "private",
            "status": "completed",
            "farm_id": 10
        })],
    }
}

#[test]
fn exports_user_data_on_success() {
    let gateway = StubGateway {
        result: Ok(sample_export()),
    };
    let mut port = RecordingPort::default();
    let mut interactor = UserDataExportInteractor::new(&mut port, &gateway);

    interactor.call(1).unwrap();

    let export = port.success.expect("expected success");
    assert!(!export.exported_at.is_empty());
    assert_eq!(export.user.email.as_deref(), Some("user@example.com"));
    assert_eq!(export.farms.len(), 1);
    assert_eq!(export.crops.len(), 1);
    assert_eq!(export.cultivation_plans.len(), 1);
    assert!(port.failure.is_none());
}

#[test]
fn emits_failure_when_gateway_errors() {
    let gateway = StubGateway {
        result: Err("user not found".into()),
    };
    let mut port = RecordingPort::default();
    let mut interactor = UserDataExportInteractor::new(&mut port, &gateway);

    interactor.call(99).unwrap();

    assert!(port.success.is_none());
    let failure = port.failure.expect("expected failure");
    assert!(failure.message.contains("user not found"));
}
