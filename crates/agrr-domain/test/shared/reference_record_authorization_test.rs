// Tests for `reference_record_authorization.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::policies::crop_policy::record_access_filter;
    use crate::shared::policies::farm_policy::record_access_filter as farm_record_access_filter;
    use crate::shared::record_ref::RecordStub;
    use crate::shared::user::User;

    #[test]
    fn assert_view_allowed_passes_when_policy_allows() {
        let user = User::new(1, false);
        let filter = record_access_filter(user, vec![]);
        let record = RecordStub {
            is_reference: true,
            user_id: Some(99),
        organization_id: None,
};
        assert!(assert_view_allowed(&filter, &record).is_ok());
    }

    #[test]
    fn assert_view_allowed_denies_other_users_non_reference() {
        let user = User::new(1, false);
        let filter = record_access_filter(user, vec![]);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(99),
        organization_id: None,
};
        assert_eq!(
            assert_view_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }

    #[test]
    fn assert_edit_allowed_denies_non_owner_private_record() {
        let user = User::new(1, false);
        let filter = record_access_filter(user, vec![]);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(99),
        organization_id: None,
};
        assert_eq!(
            assert_edit_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }

    #[test]
    fn org_member_can_view_but_not_edit_team_crop() {
        let user = User::new(2, false);
        let filter = record_access_filter(user, vec![10]);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(1),
            organization_id: Some(10),
        };
        assert!(assert_view_allowed(&filter, &record).is_ok());
        assert_eq!(
            assert_edit_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }

    #[test]
    fn org_member_can_view_but_not_edit_team_farm() {
        let user = User::new(2, false);
        let filter = farm_record_access_filter(user, vec![10]);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(1),
            organization_id: Some(10),
        };
        assert!(assert_view_allowed(&filter, &record).is_ok());
        assert_eq!(
            assert_edit_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }
