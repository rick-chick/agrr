// Tests for `validation/validation_error_hash.rs` (Ruby parity under test/domain/shared/).


    #[test]
    fn from_validation_errors() {
        let mut ve = ValidationErrors::new();
        ve.add("name", "required");
        let h = from_errors(ErrorsInput::ValidationErrors(&ve));
        assert_eq!(h.get("name").map(|v| v.as_slice()), Some(&["required".to_string()][..]));
    }
