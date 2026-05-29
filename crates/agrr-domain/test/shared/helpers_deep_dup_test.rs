// Tests for `helpers/deep_dup.rs` (Ruby parity under test/domain/shared/).

    use serde_json::json;

    #[test]
    fn distinct_nested_hashes_with_equal_content() {
        let original = json!({ "a": { "b": 1 }, "c": [1, 2] });
        let mut copy = deep_dup(&original);
        assert_eq!(original, copy);
        copy["a"]["b"] = json!(99);
        assert_eq!(original["a"]["b"], 1);
        assert_eq!(copy["a"]["b"], 99);
    }

    #[test]
    fn duplicates_strings_inside_hashes() {
        let original = json!({ "name": "x" });
        let copy = deep_dup(&original);
        let mut copy_s = copy["name"].as_str().unwrap().to_string();
        copy_s.push('y');
        assert_eq!(original["name"], "x");
    }

    #[test]
    fn leaves_nil_and_booleans() {
        assert_eq!(deep_dup(&Value::Null), Value::Null);
        assert_eq!(deep_dup(&json!(true)), json!(true));
        assert_eq!(deep_dup(&json!(false)), json!(false));
    }
