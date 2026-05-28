use crate::shared::dtos::SessionPrincipal;

/// Ruby: `Domain::Shared::Ports::MastersApiCredentialsResolveOutputPort`
pub trait MastersApiCredentialsResolveOutputPort {
    fn on_success(&mut self, principal: SessionPrincipal);
    fn on_invalid_api_key(&mut self);
    fn on_login_required(&mut self);
}
