// Tests for `type_converters/big_decimal_converter.rs` (Ruby parity under test/domain/shared/).

    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn preserves_decimal_and_handles_empty() {
        let bd = Decimal::from_str("1.25").unwrap();
        assert_eq!(cast_big_decimal_decimal(Some(bd)), Some(bd));
        assert_eq!(
            cast_big_decimal(Some("3")),
            Some(Decimal::from_str("3").unwrap())
        );
        assert_eq!(cast_big_decimal(None), None);
        assert_eq!(cast_big_decimal(Some("")), None);
    }
