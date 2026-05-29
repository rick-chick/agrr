// Tests for `policies/referencable_resource_policy.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::attr::attr_map_from_pairs;
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    #[test]
    fn visible_for_user_matches_referencable_list_rule() {
        let admin = user(1, true);
        let regular = user(9, false);
        assert!(visible_for_user(&admin, true, None));
        assert!(visible_for_user(
            &regular,
            false,
            Some(regular.id)
        ));
    }

    #[test]
    fn normalize_attrs_for_create_admin_reference_crop() {
        let admin = user(1, true);
        let h = normalize_referencable_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("RefCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
            false,
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
        assert_eq!(h.get("name"), Some(&AttrValue::from("RefCrop")));
    }

    #[test]
    fn normalize_attrs_for_create_admin_user_crop() {
        let admin = user(1, true);
        let h = normalize_referencable_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
            false,
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
    }

    #[test]
    fn normalize_attrs_for_create_regular_user_forces_owned_non_reference() {
        let regular = user(9, false);
        let h = normalize_referencable_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
            false,
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
    }

    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_referencable_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
            false,
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("us")));
    }

    #[test]
    fn normalize_attrs_for_create_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_referencable_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
            false,
        );
        assert!(!h.contains_key("region"));
    }

    #[test]
    fn normalize_attrs_for_update_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_referencable_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("in"))]),
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("in")));
    }

    #[test]
    fn normalize_attrs_for_update_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_referencable_attrs_for_update(
            &regular,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("us"))]),
        );
        assert!(!h.contains_key("region"));
    }
