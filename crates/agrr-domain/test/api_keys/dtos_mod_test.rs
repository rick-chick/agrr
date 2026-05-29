// Tests for `dtos/mod.rs` (Ruby parity under test/domain/api_keys/).


    #[test]
    fn not_found_predicate_matches_error_not_found() {
        let output = UserApiKeyRotationOutput::new(
            false,
            None,
            Some(UserApiKeyRotationError::NotFound),
        );
        assert!(output.not_found());
    }

    #[test]
    fn not_found_predicate_false_without_error() {
        let output = UserApiKeyRotationOutput::new(true, Some("k".into()), None);
        assert!(!output.not_found());
    }
