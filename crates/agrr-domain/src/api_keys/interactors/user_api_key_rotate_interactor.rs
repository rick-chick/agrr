use crate::api_keys::gateways::UserApiKeyRotationGateway;
use crate::api_keys::ports::UserApiKeyRotateOutputPort;

/// Ruby: `Domain::ApiKeys::Interactors::UserApiKeyRotateInteractor`
pub struct UserApiKeyRotateInteractor<G: UserApiKeyRotationGateway> {
    output_port: Box<dyn UserApiKeyRotateOutputPort>,
    gateway: G,
}

impl<G: UserApiKeyRotationGateway> UserApiKeyRotateInteractor<G> {
    pub fn new(output_port: Box<dyn UserApiKeyRotateOutputPort>, gateway: G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self, user_id: i64, regenerate: bool) {
        let result = self.gateway.rotate(user_id, regenerate);
        if result.not_found() {
            self.output_port
                .on_failure("User not found".to_string());
            return;
        }

        if result.ok {
            self.output_port.on_success(result.api_key.unwrap_or_default());
        } else {
            let message = if regenerate {
                "Failed to regenerate API key"
            } else {
                "Failed to generate API key"
            };
            self.output_port.on_failure(message.to_string());
        }
    }
}

#[cfg(test)]
mod interactors_user_api_key_rotate_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/api_keys/interactors_user_api_key_rotate_interactor_test.rs"));
}
