use crate::auth::dtos::{AuthTestMockLoginInput, AuthTestMockLoginPersistResult};

/// Ruby: `Domain::Auth::Gateways::AuthTestLoginGateway`
pub trait AuthTestLoginGateway: Send + Sync {
    fn persist_mock_user_and_session(
        &self,
        input_dto: &AuthTestMockLoginInput,
    ) -> AuthTestMockLoginPersistResult;
}
