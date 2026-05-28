use time::OffsetDateTime;

/// Ruby: `AuthTestMockLoginPersistResult#status` (`:success`, `:user_not_persisted`, `:record_invalid`)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthTestMockLoginPersistStatus {
    Success,
    UserNotPersisted,
    RecordInvalid,
}

/// Ruby: `Domain::Auth::Dtos::AuthTestMockLoginPersistResult`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthTestMockLoginPersistResult {
    pub status: AuthTestMockLoginPersistStatus,
    pub user_name: Option<String>,
    pub session_id: Option<String>,
    pub expires_at: Option<OffsetDateTime>,
    pub error_messages: Option<Vec<String>>,
}

impl AuthTestMockLoginPersistResult {
    pub fn success(
        user_name: impl Into<String>,
        session_id: impl Into<String>,
        expires_at: OffsetDateTime,
    ) -> Self {
        Self {
            status: AuthTestMockLoginPersistStatus::Success,
            user_name: Some(user_name.into()),
            session_id: Some(session_id.into()),
            expires_at: Some(expires_at),
            error_messages: None,
        }
    }

    pub fn user_not_persisted(error_messages: Vec<String>) -> Self {
        Self {
            status: AuthTestMockLoginPersistStatus::UserNotPersisted,
            user_name: None,
            session_id: None,
            expires_at: None,
            error_messages: Some(error_messages),
        }
    }

    pub fn record_invalid(error_messages: Vec<String>) -> Self {
        Self {
            status: AuthTestMockLoginPersistStatus::RecordInvalid,
            user_name: None,
            session_id: None,
            expires_at: None,
            error_messages: Some(error_messages),
        }
    }
}
