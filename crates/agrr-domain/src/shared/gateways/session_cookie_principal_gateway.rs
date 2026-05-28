use crate::shared::dtos::SessionPrincipal;

/// Ruby: `Domain::Shared::Gateways::SessionCookiePrincipalGateway`
pub trait SessionCookiePrincipalGateway: Send + Sync {
    /// Ruby: `#principal_for_session_cookie(session_id)`
    fn principal_for_session_cookie(&self, session_id: Option<&str>) -> SessionPrincipal;
}
