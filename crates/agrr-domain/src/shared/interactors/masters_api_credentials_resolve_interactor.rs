//! Ruby: `Domain::Shared::Interactors::MastersApiCredentialsResolveInteractor`

use crate::shared::dtos::MastersApiCredentialsResolveInput;
use crate::shared::gateways::{ApiKeyPrincipalGateway, SessionCookiePrincipalGateway};
use crate::shared::ports::MastersApiCredentialsResolveOutputPort;

/// マスター API: API キー優先、なければセッション Cookie からログイン主体を解決する。
pub struct MastersApiCredentialsResolveInteractor<'a, A, S, O> {
    output_port: &'a mut O,
    api_key_principal_gateway: &'a A,
    session_cookie_principal_gateway: &'a S,
}

impl<'a, A, S, O> MastersApiCredentialsResolveInteractor<'a, A, S, O> {
    pub fn new(
        output_port: &'a mut O,
        api_key_principal_gateway: &'a A,
        session_cookie_principal_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            api_key_principal_gateway,
            session_cookie_principal_gateway,
        }
    }

    pub fn call(&mut self, input: &MastersApiCredentialsResolveInput)
    where
        A: ApiKeyPrincipalGateway,
        S: SessionCookiePrincipalGateway,
        O: MastersApiCredentialsResolveOutputPort,
    {
        if input.api_key_present() {
            let api_key = input.api_key.as_deref().expect("api_key_present");
            if let Some(principal) = self
                .api_key_principal_gateway
                .principal_for_api_key(api_key)
            {
                self.output_port.on_success(principal);
            } else {
                self.output_port.on_invalid_api_key();
            }
            return;
        }

        let principal = self
            .session_cookie_principal_gateway
            .principal_for_session_cookie(input.session_id.as_deref());
        if principal.authenticated() {
            self.output_port.on_success(principal);
        } else {
            self.output_port.on_login_required();
        }
    }
}

#[cfg(test)]
mod interactors_masters_api_credentials_resolve_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/interactors_masters_api_credentials_resolve_interactor_test.rs"));
}
