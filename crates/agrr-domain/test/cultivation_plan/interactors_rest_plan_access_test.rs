// Tests for `interactors/rest_plan_access.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::entities::CultivationPlanEntity;

    fn plan_entity(id: i64, user_id: i64, plan_type: &str) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id,
            farm_id: 1,
            user_id,
            total_area: 0.0,
            plan_type: plan_type.into(),
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

    // Ruby: test "access_denied? delegates private plans to PrivateCultivationPlanAccessPolicy"
    #[test]
    fn access_denied_delegates_private_plans_to_policy() {
        let auth = CultivationPlanRestAuth::private(1);
        let owned = plan_entity(1, 1, "private");
        let other = plan_entity(2, 2, "private");
        assert!(!access_denied(&owned, &auth));
        assert!(access_denied(&other, &auth));
    }

    // Ruby: test "access_denied? requires public plan_type for public REST auth"
    #[test]
    fn access_denied_requires_public_plan_type_for_public_auth() {
        let auth = CultivationPlanRestAuth::public();
        let public_plan = plan_entity(1, 1, "public");
        let private_plan = plan_entity(2, 1, "private");
        assert!(!access_denied(&public_plan, &auth));
        assert!(access_denied(&private_plan, &auth));
    }
