// Tests for `policies/plan_read_authorization.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "public_plan? matches plan_type public string"
    #[test]
    fn public_plan_matches_plan_type_public_string() {
        assert!(public_plan("public"));
        assert!(!public_plan("private"));
    }
