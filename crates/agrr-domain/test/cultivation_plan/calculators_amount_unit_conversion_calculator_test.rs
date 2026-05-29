// Tests for `calculators/amount_unit_conversion_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "convert_per_area_amount converts kg/ha to g/m2"
    #[test]
    fn convert_per_area_amount_converts_kg_ha_to_g_m2() {
        let calc = AmountUnitConversionCalculator;
        let result = calc
            .convert_per_area_amount(Decimal::ONE, "kg/ha", "g/m2")
            .unwrap();
        let f: f64 = result.to_string().parse().unwrap();
        assert!((f - 0.1).abs() < 0.0001);
    }

    // Ruby: test "apply_to_update_attributes converts when amount param matches current"
    #[test]
    fn apply_to_update_attributes_converts_when_amount_param_matches() {
        let calc = AmountUnitConversionCalculator;
        let mut attrs = BTreeMap::new();
        attrs.insert("amount_unit".into(), "g/m2".into());
        attrs.insert("amount".into(), "1.0".into());
        let converted = calc
            .apply_to_update_attributes(
                &attrs,
                Some(Decimal::ONE),
                Some("kg/ha"),
                Some("g/m2"),
                Some("1.0"),
            )
            .unwrap();
        let f: f64 = converted["amount"].parse().unwrap();
        assert!((f - 0.1).abs() < 0.0001);
    }

    // Ruby: test "apply_to_update_attributes returns nil when units match"
    #[test]
    fn apply_to_update_attributes_returns_none_when_units_match() {
        let calc = AmountUnitConversionCalculator;
        let mut attrs = BTreeMap::new();
        attrs.insert("amount_unit".into(), "kg/ha".into());
        assert!(
            calc.apply_to_update_attributes(
                &attrs,
                Some(Decimal::ONE),
                Some("kg/ha"),
                Some("kg/ha"),
                None,
            )
            .is_none()
        );
    }
