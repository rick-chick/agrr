//! Ruby: `Domain::ApiKeys::Gateways`

mod user_api_key_rotation_gateway;

pub use user_api_key_rotation_gateway::UserApiKeyRotationGateway;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api_keys::dtos::UserApiKeyRotationOutput;

    fn assert_send_sync<T: Send + Sync + ?Sized>() {}

    struct NoopGateway;

    impl UserApiKeyRotationGateway for NoopGateway {
        fn rotate(&self, _: i64, _: bool) -> UserApiKeyRotationOutput {
            UserApiKeyRotationOutput::new(false, None, None)
        }
    }

    #[test]
    fn user_api_key_rotation_gateway_is_object_safe() {
        assert_send_sync::<dyn UserApiKeyRotationGateway>();
        let _gw: &dyn UserApiKeyRotationGateway = &NoopGateway;
    }
}
