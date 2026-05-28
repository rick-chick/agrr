use crate::api_keys::dtos::UserApiKeyRotationOutput;

/// Ruby: `Domain::ApiKeys::Gateways::UserApiKeyRotationGateway`
pub trait UserApiKeyRotationGateway: Send + Sync {
    fn rotate(&self, user_id: i64, regenerate: bool) -> UserApiKeyRotationOutput;
}
