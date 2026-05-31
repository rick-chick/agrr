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

    // Ruby: duplicate_name_record? は既存なしなら false
    #[test]
    fn duplicate_name_record_returns_false_when_no_existing() {
        assert!(!duplicate_name_record(None, None));
    }

    // Ruby: duplicate_name_record? は作成時に既存があれば true
    #[test]
    fn duplicate_name_record_returns_true_on_create_when_existing() {
        assert!(duplicate_name_record(Some(1), None));
    }

    // Ruby: duplicate_name_record? は更新時に同一 ID なら false
    #[test]
    fn duplicate_name_record_returns_false_on_update_same_id() {
        assert!(!duplicate_name_record(Some(5), Some(5)));
    }

    // Ruby: duplicate_name_record? は更新時に別 ID なら true
    #[test]
    fn duplicate_name_record_returns_true_on_update_different_id() {
        assert!(duplicate_name_record(Some(1), Some(5)));
    }

    // Ruby: reference_assignment_allowed? は非参照なら誰でも true
    #[test]
    fn reference_assignment_allowed_for_non_reference() {
        assert!(reference_assignment_allowed(&user(9, false), false));
    }

    // Ruby: reference_assignment_allowed? は参照付与を admin のみ許可する
    #[test]
    fn reference_assignment_allowed_reference_only_for_admin() {
        assert!(reference_assignment_allowed(&user(1, true), true));
        assert!(!reference_assignment_allowed(&user(9, false), true));
    }

    // Ruby: reference_flag_change_allowed? は変更なしなら true
    #[test]
    fn reference_flag_change_allowed_when_unchanged() {
        assert!(reference_flag_change_allowed(&user(9, false), false, false));
        assert!(reference_flag_change_allowed(&user(9, false), true, true));
    }

    // Ruby: reference_flag_change_allowed? はフラグ変更を admin のみ許可する
    #[test]
    fn reference_flag_change_allowed_change_only_for_admin() {
        assert!(reference_flag_change_allowed(&user(1, true), true, false));
        assert!(!reference_flag_change_allowed(&user(9, false), true, false));
    }

    // Ruby: create 正規化: admin_forced は admin と同等に扱う
    #[test]
    fn normalize_attrs_for_create_admin_forced_treats_as_admin() {
        let regular = user(9, false);
        let h = normalize_referencable_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("is_reference", AttrValue::Bool(true)),
                ("region", AttrValue::from("us")),
            ]),
            true,
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
        assert_eq!(h.get("region"), Some(&AttrValue::from("us")));
    }

    // Ruby: update 正規化: 参照化は user_id=nil、参照解除は操作ユーザーを設定
    #[test]
    fn normalize_attrs_for_update_reference_flag_transitions() {
        let admin = user(1, true);
        let to_ref = normalize_referencable_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
        );
        assert_eq!(to_ref.get("user_id"), Some(&AttrValue::Null));
        assert_eq!(to_ref.get("is_reference"), Some(&AttrValue::Bool(true)));

        let from_ref = normalize_referencable_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
        );
        assert_eq!(from_ref.get("user_id"), Some(&AttrValue::Int(1)));
        assert_eq!(from_ref.get("is_reference"), Some(&AttrValue::Bool(false)));
    }

    // Ruby: update 正規化: is_reference に変更が無ければそのキーを落とす
    #[test]
    fn normalize_attrs_for_update_drops_unchanged_is_reference() {
        let admin = user(1, true);
        let h = normalize_referencable_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([
                ("is_reference", AttrValue::Bool(false)),
                ("name", AttrValue::from("x")),
            ]),
        );
        assert!(!h.contains_key("is_reference"));
        assert_eq!(h.get("name"), Some(&AttrValue::from("x")));
    }

    // Ruby: reference_record_user_id_valid? は参照なら user_id nil のみ許可
    #[test]
    fn reference_record_user_id_valid_for_reference() {
        assert!(reference_record_user_id_valid(true, None));
        assert!(!reference_record_user_id_valid(true, Some(1)));
    }

    // Ruby: reference_record_user_id_valid? は非参照なら user_id 必須
    #[test]
    fn reference_record_user_id_valid_for_non_reference() {
        assert!(reference_record_user_id_valid(false, Some(9)));
        assert!(!reference_record_user_id_valid(false, None));
    }
