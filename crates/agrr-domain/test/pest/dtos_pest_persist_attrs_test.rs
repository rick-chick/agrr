// Tests for `dtos/pest_persist_attrs.rs` (Ruby parity under test/domain/pest/).

    use crate::shared::attr::attr_map_from_pairs;

    // Ruby: test "from_normalized_hash keeps only known keys and exposes readers"
    #[test]
    fn from_normalized_hash_keeps_only_known_keys() {
        let dto = PestPersistAttrs::from_normalized_hash(attr_map_from_pairs([
            ("name", AttrValue::from("アブラムシ")),
            ("user_id", AttrValue::Int(9)),
            ("is_reference", AttrValue::Bool(false)),
            ("ignored_extra", AttrValue::from("x")),
        ]));
        assert_eq!(
            dto.name().and_then(|v| v.as_str()),
            Some("アブラムシ")
        );
        assert_eq!(dto.user_id(), Some(&AttrValue::Int(9)));
        assert_eq!(dto.is_reference(), Some(&AttrValue::Bool(false)));
        assert!(!dto.to_ar_attributes().contains_key("ignored_extra"));
    }

    // Ruby: test "to_ar_attributes returns mutable dup"
    #[test]
    fn to_ar_attributes_returns_mutable_dup() {
        let dto = PestPersistAttrs::from_normalized_hash(attr_map_from_pairs([
            ("name", AttrValue::from("x")),
            ("user_id", AttrValue::Int(1)),
            ("is_reference", AttrValue::Bool(false)),
        ]));
        let mut h = dto.to_ar_attributes();
        h.insert("name".into(), AttrValue::from("y"));
        assert_eq!(
            dto.name().and_then(|v| v.as_str()),
            Some("x")
        );
    }
