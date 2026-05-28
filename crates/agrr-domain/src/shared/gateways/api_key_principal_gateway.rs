use crate::shared::dtos::SessionPrincipal;

/// Ruby: `Domain::Shared::Gateways::ApiKeyPrincipalGateway`
pub trait ApiKeyPrincipalGateway: Send + Sync {
    /// Ruby: `#principal_for_api_key(api_key)` — `SessionPrincipal` or nil
    fn principal_for_api_key(&self, api_key: &str) -> Option<SessionPrincipal>;
}
