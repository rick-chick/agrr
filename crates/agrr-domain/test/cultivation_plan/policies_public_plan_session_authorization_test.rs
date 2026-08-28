    #[test]
    fn session_matches_when_equal() {
        assert!(session_matches(Some("abc123"), "abc123"));
    }

    #[test]
    fn session_mismatch_when_different() {
        assert!(!session_matches(Some("abc123"), "other"));
    }

    #[test]
    fn session_mismatch_when_plan_missing_session() {
        assert!(!session_matches(None, "abc123"));
    }

    #[test]
    fn session_mismatch_when_request_empty() {
        assert!(!session_matches(Some("abc123"), ""));
    }
