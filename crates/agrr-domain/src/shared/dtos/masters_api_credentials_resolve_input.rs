/// Ruby: `Domain::Shared::Dtos::MastersApiCredentialsResolveInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MastersApiCredentialsResolveInput {
    pub api_key: Option<String>,
    pub session_id: Option<String>,
}

impl MastersApiCredentialsResolveInput {
    pub fn new(api_key: Option<String>, session_id: Option<String>) -> Self {
        Self {
            api_key,
            session_id,
        }
    }

    pub fn api_key_present(&self) -> bool {
        self.api_key
            .as_ref()
            .is_some_and(|key| !key.trim().is_empty())
    }
}

#[cfg(test)]
mod dtos_masters_api_credentials_resolve_input_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/dtos_masters_api_credentials_resolve_input_test.rs"));
}
