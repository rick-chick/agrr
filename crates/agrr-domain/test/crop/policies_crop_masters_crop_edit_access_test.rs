// Tests for `policies/crop_masters_crop_edit_access.rs` (Ruby parity under test/domain/crop/).

    use crate::shared::policies::crop_policy;
    use crate::shared::user::User;

    fn crop(user_id: i64) -> CropEntity {
        CropEntity {
            id: 1,
            user_id: Some(user_id),
            name: "Tomato".into(),
            variety: None,
            is_reference: false,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "assert_edit! passes for owner"
    #[test]
    fn assert_edit_passes_for_owner() {
        let user = User::new(1, false);
        let filter = crop_policy::record_access_filter(user);
        assert!(assert_edit(&filter, &crop(1)).is_ok());
    }

    // Ruby: test "assert_edit_or_on_failure calls on_failure when denied"
    #[test]
    fn assert_edit_or_on_failure_calls_on_failure_when_denied() {
        let user = User::new(1, false);
        let filter = crop_policy::record_access_filter(user);
        let mut called = false;
        let ok = assert_edit_or_on_failure(&filter, &crop(99), || called = true);
        assert!(!ok);
        assert!(called);
    }
