// Tests for `policies/crop_nested_pests_access.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::record_ref::RecordStub;
    use crate::shared::user::User;


    struct EmptyScopeGateway;
    impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
        fn organization_ids_for_user(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }
    #[test]
    fn assert_allowed_passes_for_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: true,
            user_id: Some(99),
        organization_id: None,
};
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_passes_for_crop_owner() {
        let user = User::new(1, false);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(1),
        organization_id: None,
};
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_denies_admin_on_another_users_non_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(99),
        organization_id: None,
};
        assert_eq!(assert_allowed(&user, &crop), Err(PolicyPermissionDenied));
    }
