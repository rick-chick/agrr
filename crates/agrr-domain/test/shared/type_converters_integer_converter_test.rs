// Tests for `type_converters/integer_converter.rs` (Ruby parity under test/domain/shared/).

    use serde_json::json;

    #[test]
    fn cast_digit_strings_and_rejects_non_digits() {
        assert_eq!(cast_integer(Some(&json!("42"))), Some(42));
        assert_eq!(cast_integer(Some(&json!("-3"))), Some(-3));
        assert_eq!(cast_integer(Some(&json!("12.5"))), None);
        assert_eq!(cast_integer(None), None);
        assert_eq!(cast_integer(Some(&json!(7))), Some(7));
    }
