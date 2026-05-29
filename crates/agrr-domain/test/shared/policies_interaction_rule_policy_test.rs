// Tests for `policies/interaction_rule_policy.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::attr::attr_map_from_pairs;
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
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
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "normalize_attrs_for_create は参照ルールを user_id=nil にする"
    #[test]
    fn normalize_attrs_for_create_reference_rule_sets_user_id_null() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
    }

    // Ruby: test "normalize_attrs_for_create は非参照ルールを呼び出しユーザー所有にする"
    #[test]
    fn normalize_attrs_for_create_non_reference_rule_owned_by_caller() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
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

    // Ruby: test "normalize_attrs_for_update は参照化のとき user_id を nil にする"
    #[test]
    fn normalize_attrs_for_update_reference_sets_user_id_null() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
    }

    // Ruby: test "normalize_attrs_for_update は参照解除のとき user_id を操作ユーザーにする"
    #[test]
    fn normalize_attrs_for_update_dereference_sets_user_id_to_operator() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
    }

    // Ruby: test "view_allowed? は admin と所有者に許可する"
    #[test]
    fn view_allowed_for_admin_and_owner() {
        let admin = user(1, true);
        let regular = user(9, false);
        assert!(view_allowed(&admin, false, Some(999)));
        assert!(view_allowed(&regular, false, Some(9)));
        assert!(!view_allowed(&regular, false, Some(999)));
    }

    // Ruby: test "edit_allowed? は一般ユーザーの参照ルール編集を拒否する"
    #[test]
    fn edit_allowed_denies_reference_for_regular_user() {
        let admin = user(1, true);
        let regular = user(9, false);
        assert!(edit_allowed(&admin, true, None));
        assert!(!edit_allowed(&regular, true, None));
        assert!(edit_allowed(&regular, false, Some(9)));
    }
