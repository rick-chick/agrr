//! Ruby: `Domain::ApiKeys::Gateways`

pub(crate) mod user_api_key_rotation_gateway;

pub use user_api_key_rotation_gateway::UserApiKeyRotationGateway;

#[cfg(test)]
mod gateways_mod_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/api_keys/gateways_mod_test.rs"));
}
