// Tests for `dtos/reference_flag_change_denied_failure.rs` (Ruby parity under test/domain/shared/).


    #[test]
    fn exposes_message_and_resource_id() {
        let dto = ReferenceFlagChangeDeniedFailure::new("admin only", 42);
        assert_eq!(dto.message, "admin only");
        assert_eq!(dto.resource_id, 42);
    }
