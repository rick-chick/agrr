// Tests for `validation/validation_errors.rs` (Ruby parity under test/domain/shared/).


    #[test]
    fn add_and_full_messages() {
        let mut e = ValidationErrors::new();
        e.add("name", "can't be blank");
        assert_eq!(e.get("name"), vec!["can't be blank"]);
        assert_eq!(e.full_messages(), vec!["can't be blank"]);
        assert!(e.any());
    }
