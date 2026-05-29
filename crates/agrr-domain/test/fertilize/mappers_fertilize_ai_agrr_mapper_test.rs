// Tests for `mappers/fertilize_ai_agrr_mapper.rs` (Ruby parity under test/domain/fertilize/).

    use serde_json::json;

    #[test]
    fn normalizes_nested_fertilize_payload() {
        let info = json!({
            "fertilize": { "name": "尿素", "n": 46.0, "package_size": "25kg" }
        });
        let data = normalize_fertilize_payload(&info).expect("payload");
        assert_eq!(data.get("name").and_then(|v| v.as_str()), Some("尿素"));
        assert_eq!(data.get("package_size").and_then(|v| v.as_f64()), Some(25.0));
    }

    #[test]
    fn parses_npk_string_from_direct_keys() {
        let info = json!({ "name": "配合", "npk": "20-10-5" });
        let data = normalize_fertilize_payload(&info).expect("payload");
        assert_eq!(data.get("n").and_then(|v| v.as_f64()), Some(20.0));
        assert_eq!(data.get("p").and_then(|v| v.as_f64()), Some(10.0));
        assert_eq!(data.get("k").and_then(|v| v.as_f64()), Some(5.0));
    }

    #[test]
    fn returns_none_for_empty_payload() {
        assert!(normalize_fertilize_payload(&json!({})).is_none());
    }
