use crate::auth::dtos::{AuthTestMockLoginInput, AuthTestMockLoginPersistStatus};
use crate::auth::gateways::AuthTestLoginGateway;
use crate::auth::ports::{AuthTestMockLoginOutputPort, OauthConversionUrlAppenderPort};

/// Ruby: `Domain::Auth::Interactors::AuthTestMockLoginInteractor`
pub struct AuthTestMockLoginInteractor<'a> {
    output_port: &'a mut dyn AuthTestMockLoginOutputPort,
    gateway: &'a dyn AuthTestLoginGateway,
    oauth_url_appender: &'a dyn OauthConversionUrlAppenderPort,
}

impl<'a> AuthTestMockLoginInteractor<'a> {
    pub fn new(
        output_port: &'a mut dyn AuthTestMockLoginOutputPort,
        gateway: &'a dyn AuthTestLoginGateway,
        oauth_url_appender: &'a dyn OauthConversionUrlAppenderPort,
    ) -> Self {
        Self {
            output_port,
            gateway,
            oauth_url_appender,
        }
    }

    pub fn call(&mut self, input_dto: &AuthTestMockLoginInput, environment_allowed: bool) {
        if !environment_allowed {
            self.output_port.on_environment_forbidden();
            return;
        }

        if input_dto.google_id.is_empty() {
            self.output_port.on_missing_mock();
            return;
        }

        let result = self.gateway.persist_mock_user_and_session(input_dto);

        match result.status {
            AuthTestMockLoginPersistStatus::Success => {
                let session_id = result.session_id.as_deref().unwrap_or_default();
                let expires_at = result.expires_at.expect("success result requires expires_at");
                if input_dto.stashed_public_plan {
                    self.output_port
                        .on_success_process_saved_plan(session_id, expires_at);
                } else if let Some(pending) = input_dto.pending_return_to.as_deref() {
                    if input_dto.pending_return_to_allowed {
                        let url = self.oauth_url_appender.append(pending);
                        let user_name = result.user_name.as_deref().unwrap_or_default();
                        self.output_port.on_success_return_to(
                            &url,
                            session_id,
                            expires_at,
                            user_name,
                        );
                    } else {
                        let user_name = result.user_name.as_deref().unwrap_or_default();
                        self.output_port
                            .on_success_root(session_id, expires_at, user_name);
                    }
                } else {
                    let user_name = result.user_name.as_deref().unwrap_or_default();
                    self.output_port
                        .on_success_root(session_id, expires_at, user_name);
                }
            }
            AuthTestMockLoginPersistStatus::UserNotPersisted
            | AuthTestMockLoginPersistStatus::RecordInvalid => {
                let messages: Vec<String> = result
                    .error_messages
                    .unwrap_or_default()
                    .into_iter()
                    .filter(|m| !m.is_empty())
                    .collect();
                self.output_port.on_create_failed(messages);
            }
        }
    }
}

#[cfg(test)]
mod interactors_auth_test_mock_login_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/auth/interactors_auth_test_mock_login_interactor_test.rs"));
}
