// Tests for `policies/crop_nested_pests_access.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::record_ref::RecordStub;
    use crate::shared::user::User;

    #[test]
    fn assert_allowed_passes_for_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: true,
            user_id: Some(99),
        };
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_passes_for_crop_owner() {
        let user = User::new(1, false);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(1),
        };
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_denies_admin_on_another_users_non_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(99),
        };
        assert_eq!(assert_allowed(&user, &crop), Err(PolicyPermissionDenied));
    }
