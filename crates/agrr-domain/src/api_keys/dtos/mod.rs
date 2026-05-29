//! Ruby: `Domain::ApiKeys::Dtos`

pub(crate) mod user_api_key_rotation_output;

pub use user_api_key_rotation_output::{UserApiKeyRotationError, UserApiKeyRotationOutput};

#[cfg(test)]
mod dtos_mod_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/api_keys/dtos_mod_test.rs"));
}
