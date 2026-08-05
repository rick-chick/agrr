/// Ruby: `Domain::ApiKeys::Dtos::UserApiKeyRotationOutput`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UserApiKeyRotationError {
    NotFound,
}

/// Ruby: `UserApiKeyRotationGateway#rotate` return value.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserApiKeyRotationOutput {
    pub ok: bool,
    pub api_key: Option<String>,
    pub scopes: Option<Vec<String>>,
    pub error: Option<UserApiKeyRotationError>,
}

impl UserApiKeyRotationOutput {
    pub const ERROR_NOT_FOUND: UserApiKeyRotationError = UserApiKeyRotationError::NotFound;

    pub fn new(
        ok: bool,
        api_key: Option<String>,
        scopes: Option<Vec<String>>,
        error: Option<UserApiKeyRotationError>,
    ) -> Self {
        Self {
            ok,
            api_key,
            scopes,
            error,
        }
    }

    pub fn not_found(&self) -> bool {
        self.error == Some(UserApiKeyRotationError::NotFound)
    }
}
