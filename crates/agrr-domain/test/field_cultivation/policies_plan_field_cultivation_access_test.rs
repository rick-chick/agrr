// Tests for `policies/plan_field_cultivation_access.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::FieldCultivationPlanAccessSnapshot;

    fn public_snapshot(fc_id: i64) -> FieldCultivationPlanAccessSnapshot {
        FieldCultivationPlanAccessSnapshot::new(fc_id, true, false, None)
    }

    fn private_snapshot(fc_id: i64, plan_user_id: i64) -> FieldCultivationPlanAccessSnapshot {
        FieldCultivationPlanAccessSnapshot::new(fc_id, false, true, Some(plan_user_id))
    }

    #[test]
    fn allows_view_for_public_plan() {
        let context = public_snapshot(1);
        let user = User::new(99, false);
        assert!(view_allowed(&user, &context));
        assert!(assert_view_allowed(&user, &context).is_ok());
    }

    #[test]
    fn allows_view_and_edit_for_plan_owner_on_private_plan() {
        let context = private_snapshot(1, 5);
        let user = User::new(5, false);
        assert!(view_allowed(&user, &context));
        assert!(assert_view_allowed(&user, &context).is_ok());
        assert!(assert_edit_allowed(&user, &context).is_ok());
    }

    #[test]
    fn denies_view_for_non_owner_on_private_plan() {
        let context = private_snapshot(1, 5);
        let user = User::new(99, false);
        assert!(!view_allowed(&user, &context));
        assert_eq!(
            assert_view_allowed(&user, &context),
            Err(PolicyPermissionDenied)
        );
    }

    #[test]
    fn allows_admin_on_private_plan_owned_by_another_user() {
        let context = private_snapshot(1, 5);
        let admin = User::new(99, true);
        assert!(view_allowed(&admin, &context));
    }
