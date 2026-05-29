use crate::auth::gateways::UserSessionRevocationGateway;
use crate::auth::ports::AuthUserLogoutOutputPort;

/// Ruby: `Domain::Auth::Interactors::AuthUserLogoutInteractor`
pub struct AuthUserLogoutInteractor<'a> {
    output_port: &'a mut dyn AuthUserLogoutOutputPort,
    session_revocation_gateway: &'a dyn UserSessionRevocationGateway,
}

impl<'a> AuthUserLogoutInteractor<'a> {
    pub fn new(
        output_port: &'a mut dyn AuthUserLogoutOutputPort,
        session_revocation_gateway: &'a dyn UserSessionRevocationGateway,
    ) -> Self {
        Self {
            output_port,
            session_revocation_gateway,
        }
    }

    pub fn call(&mut self, authenticated: bool, user_id: i64) {
        if !authenticated {
            self.output_port.on_not_logged_in();
            return;
        }

        self.session_revocation_gateway
            .delete_all_sessions_for_user(user_id);
        self.output_port.on_success();
    }
}

#[cfg(test)]
mod interactors_auth_user_logout_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/auth/interactors_auth_user_logout_interactor_test.rs"));
}
