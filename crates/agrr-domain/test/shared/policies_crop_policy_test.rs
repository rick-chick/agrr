// Tests for `policies/crop_policy.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::attr::{attr_map_from_pairs, AttrValue};
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    #[test]
    fn view_allowed_for_admin() {
        let admin = user(1, true);
        assert!(view_allowed(&admin, false, Some(999)));
    }

    #[test]
    fn view_allowed_for_reference_crop() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, true, None));
    }

    #[test]
    fn view_allowed_for_own_crop() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, false, Some(9)));
    }

    #[test]
    fn view_allowed_denies_other_user_non_reference_crop() {
        let regular = user(9, false);
        assert!(!view_allowed(&regular, false, Some(999)));
    }

    #[test]
    fn edit_allowed_for_own_non_reference() {
        let regular = user(9, false);
        assert!(edit_allowed(&regular, false, Some(9)));
    }

    // Ruby: test "normalize_attrs_for_create for admin with reference crop"
    #[test]
    fn normalize_attrs_for_create_admin_reference_crop() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("RefCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
        assert_eq!(h.get("name"), Some(&AttrValue::from("RefCrop")));
    }

    // Ruby: test "normalize_attrs_for_create for admin with user crop (non-reference)"
    #[test]
    fn normalize_attrs_for_create_admin_user_crop() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("UserCrop")));
    }

    // Ruby: test "normalize_attrs_for_create for regular user always creates non-reference crop owned by user"
    #[test]
    fn normalize_attrs_for_create_regular_user_forces_owned_non_reference() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("UserCrop")));
    }

    // Ruby: test "normalize_attrs_for_create は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("us")));
    }

    // Ruby: test "normalize_attrs_for_create は一般ユーザーの region を破棄する"
    #[test]
    fn normalize_attrs_for_create_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "normalize_attrs_for_update は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_update_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("in"))]),
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("in")));
    }

    // Ruby: test "normalize_attrs_for_update は一般ユーザーの region を破棄する"
    #[test]
    fn normalize_attrs_for_update_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_attrs_for_update(
            &regular,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("us"))]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "crop_associable_with_pest? matches reference and ownership rules"
    #[test]
    fn crop_associable_with_pest_matches_reference_and_ownership_rules() {
        let user = user(1, false);

        assert!(crop_associable_with_pest(
            &user, true, None, None, true, None, None,
        ));

        assert!(!crop_associable_with_pest(
            &user, false, Some(1), None, true, None, None,
        ));

        assert!(crop_associable_with_pest(
            &user, true, None, None, false, Some(1), None,
        ));

        assert!(crop_associable_with_pest(
            &user, false, Some(2), None, false, Some(2), None,
        ));
    }

    // Ruby: test "region mismatch denies"
    #[test]
    fn crop_associable_with_pest_region_mismatch_denies() {
        let user = user(1, false);
        assert!(!crop_associable_with_pest(
            &user, true, None, Some("us"), true, None, Some("jp"),
        ));
    }

    // Ruby: test "ai_affected_crop_linkable? allows reference crop for anonymous user path"
    #[test]
    fn ai_affected_crop_linkable_allows_reference_crop() {
        let user = user(1, false);
        assert!(ai_affected_crop_linkable(
            Some(&user),
            true,
            None,
            None,
            false,
            Some(1),
            None,
        ));
    }
