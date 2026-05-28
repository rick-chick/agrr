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
mod tests {
    use super::*;

    #[test]
    fn api_key_present_when_non_empty_after_trim() {
        let input = MastersApiCredentialsResolveInput::new(
            Some("key-1".into()),
            Some("sess".into()),
        );
        assert!(input.api_key_present());
    }

    #[test]
    fn api_key_absent_when_none_empty_or_whitespace() {
        assert!(
            !MastersApiCredentialsResolveInput::new(None, None).api_key_present()
        );
        assert!(
            !MastersApiCredentialsResolveInput::new(Some(String::new()), None).api_key_present()
        );
        assert!(
            !MastersApiCredentialsResolveInput::new(Some("   ".into()), None).api_key_present()
        );
    }
}
