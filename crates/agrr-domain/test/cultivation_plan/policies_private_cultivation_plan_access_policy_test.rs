// Tests for `policies/private_cultivation_plan_access_policy.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::entities::CultivationPlanEntity;
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
    fn private_plan_entity(user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 10,
            farm_id: 1,
            user_id,
        organization_id: None,
total_area: 100.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: None,
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "access_denied? is false when user owns a private plan"
    #[test]
    fn access_denied_false_when_user_owns_private_plan() {
        assert!(!access_denied(&private_plan_entity(5), 5, &[]));
    }

    // Ruby: test "access_denied? is true when user_id does not match"
    #[test]
    fn access_denied_true_when_user_id_mismatch() {
        assert!(access_denied(&private_plan_entity(5), 99, &[]));
    }

    // Ruby: test "access_denied? is true when plan is not private"
    #[test]
    fn access_denied_true_when_plan_not_private() {
        let mut plan = private_plan_entity(5);
        plan.plan_type = "public".into();
        assert!(access_denied(&plan, 5, &[]));
    }

    // Ruby: test "assert_private_owned! raises PolicyPermissionDenied when access_denied?"
    #[test]
    fn assert_private_owned_raises_when_access_denied() {
        let user = User::new(1, false);
        let plan = private_plan_entity(2);
        assert_eq!(assert_private_owned(&user, &plan, &[]), Err(PolicyPermissionDenied));
    }

    #[test]
    fn access_denied_false_when_org_member_matches_plan_organization() {
        let mut plan = private_plan_entity(5);
        plan.organization_id = Some(42);
        assert!(!access_denied(&plan, 99, &[42]));
    }

    #[test]
    fn access_denied_true_when_org_member_does_not_match_plan_organization() {
        let mut plan = private_plan_entity(5);
        plan.organization_id = Some(42);
        assert!(access_denied(&plan, 99, &[7]));
    }

    #[test]
    fn access_denied_true_when_plan_has_no_organization_and_user_is_not_owner() {
        let plan = private_plan_entity(5);
        assert!(access_denied(&plan, 99, &[42]));
    }

    #[test]
    fn assert_private_owned_allows_org_member_with_matching_organization() {
        let user = User::new(99, false);
        let mut plan = private_plan_entity(5);
        plan.organization_id = Some(42);
        assert_eq!(assert_private_owned(&user, &plan, &[42]), Ok(()));
    }
