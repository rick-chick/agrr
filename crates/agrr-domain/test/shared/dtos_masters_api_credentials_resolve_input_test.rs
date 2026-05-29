// Tests for `dtos/masters_api_credentials_resolve_input.rs` (Ruby parity under test/domain/shared/).


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
