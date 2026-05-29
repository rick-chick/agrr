// Tests for `type_converters/boolean_converter.rs` (Ruby parity under test/domain/shared/).


    #[test]
    fn cast_truthy_strings() {
        assert!(cast_boolean_str("true"));
        assert!(cast_boolean_str("1"));
    }

    #[test]
    fn cast_falsy_nil_and_empty() {
        assert!(!cast_boolean(&serde_json::Value::Null));
        assert!(!cast_boolean_str(""));
    }
