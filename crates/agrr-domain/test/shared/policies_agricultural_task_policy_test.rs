// Tests for `policies/agricultural_task_policy.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::attr::{attr_map_from_pairs, AttrValue};
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create for regular user"
    #[test]
    fn normalize_attrs_for_create_for_regular_user() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("T")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? allows reference task for another owner"
    #[test]
    fn masters_crop_task_template_associate_allowed_allows_reference_task_for_another_owner() {
        let regular = user(9, false);
        assert!(masters_crop_task_template_associate_allowed(
            &regular,
            true,
            Some(99)
        ));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? allows own non-reference task"
    #[test]
    fn masters_crop_task_template_associate_allowed_allows_own_non_reference_task() {
        let regular = user(9, false);
        assert!(masters_crop_task_template_associate_allowed(
            &regular,
            false,
            Some(9)
        ));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? rejects other user non-reference task"
    #[test]
    fn masters_crop_task_template_associate_allowed_rejects_other_user_non_reference_task() {
        let regular = user(9, false);
        assert!(!masters_crop_task_template_associate_allowed(
            &regular,
            false,
            Some(99)
        ));
    }

    // Ruby: test "view_allowed? for own task"
    #[test]
    fn view_allowed_for_own_task() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, false, Some(9)));
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
