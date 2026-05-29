// Tests for `validation/validation_helpers.rs` (Ruby parity under test/domain/shared/).

    use serde_json::json;

    #[test]
    fn blank_and_present_match_ruby_contract() {
        assert!(blank(&Value::Null));
        assert!(blank(&json!(false)));
        assert!(!blank(&json!(true)));
        assert!(blank(&json!("")));
        assert!(blank(&json!("   ")));
        assert!(!blank(&json!("test")));
        assert!(blank(&json!([])));
        assert!(blank(&json!({})));
        assert!(!blank(&json!([1])));
        assert!(!blank(&json!({"a": 1})));
        assert!(!blank(&json!(42)));
        assert!(present(&json!("test")));
        assert!(!present(&Value::Null));
        assert!(!present(&json!("")));
    }

    #[test]
    fn to_array_matches_ruby_contract() {
        assert_eq!(to_array_value(None), Vec::<Value>::new());
        let arr = vec![json!(1), json!(2), json!(3)];
        assert_eq!(to_array_value(Some(&Value::Array(arr.clone()))), arr);
        assert_eq!(to_array_value(Some(&json!(1))), vec![json!(1)]);
        assert_eq!(to_array_value(Some(&json!("test"))), vec![json!("test")]);
    }
