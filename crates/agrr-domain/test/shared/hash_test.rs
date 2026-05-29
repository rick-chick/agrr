// Tests for `hash.rs` (Ruby parity under test/domain/shared/).

    use serde_json::json;

    #[test]
    fn blank_nil_and_false() {
        assert!(blank(&Value::Null));
        assert!(blank(&json!(false)));
    }

    #[test]
    fn blank_whitespace_string() {
        assert!(blank(&json!("   ")));
        assert!(!blank(&json!("test")));
    }

    #[test]
    fn present_is_inverse_of_blank() {
        assert!(present(&json!("test")));
        assert!(!present(&Value::Null));
    }

    #[test]
    fn to_array_nil_and_wrap() {
        assert_eq!(to_array(None), Vec::<Value>::new());
        assert_eq!(to_array(Some(&json!(1))), vec![json!(1)]);
        let arr = vec![json!(1), json!(2)];
        assert_eq!(to_array(Some(&Value::Array(arr.clone()))), arr);
    }

    #[test]
    fn deep_symbolize_keys_recurses() {
        let h = json!({ "outer": { "inner": [ { "x": 1 } ] } });
        let out = deep_symbolize_keys(&h);
        assert_eq!(out, h);
    }

    #[test]
    fn symbolize_keys_empty_for_none() {
        assert!(symbolize_keys(None).is_empty());
    }

    #[test]
    fn stringify_keys_top_level() {
        let mut map = BTreeMap::new();
        map.insert("a".into(), json!(1));
        map.insert("b".into(), json!(2));
        let out = stringify_keys(Some(&map));
        assert_eq!(out.get("a"), Some(&json!(1)));
        assert_eq!(out.get("b"), Some(&json!(2)));
    }

    #[test]
    fn blank_array_and_hash() {
        assert!(blank(&json!([])));
        assert!(blank(&json!({})));
        assert!(!blank(&json!([1])));
    }
