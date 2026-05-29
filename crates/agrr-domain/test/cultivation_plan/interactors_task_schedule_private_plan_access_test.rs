// Tests for `interactors/task_schedule_private_plan_access.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use crate::cultivation_plan::gateways::CultivationPlanGateway;
    use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
    use crate::shared::exceptions::RecordNotFoundError;
    use crate::shared::user::User;
    use serde_json::Value;
    use std::collections::HashMap;

    struct StubGateway {
        plan: Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>,
    }

    impl CultivationPlanGateway for StubGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.plan {
                Ok(p) => Ok(p.clone()),
                Err(e) => Err(Box::new(RecordNotFoundError)),
            }
        }

        fn create(
            &self,
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<crate::cultivation_plan::entities::FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }

        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            block()
        }

        fn private_owned_plan_display_name(
            &self,
            _: &User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(
            &self,
            _: i64,
            _: &User,
            _: &str,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    fn private_plan(user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 2,
            farm_id: 1,
            user_id,
            total_area: 0.0,
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

    // Ruby: test "access_allowed? is true for private plan owned by user"
    #[test]
    fn access_allowed_true_for_owned_private_plan() {
        let gateway = StubGateway {
            plan: Ok(private_plan(1)),
        };
        assert!(access_allowed(&gateway, 2, 1));
    }

    // Ruby: test "access_allowed? is false for another users private plan"
    #[test]
    fn access_allowed_false_for_other_users_plan() {
        let gateway = StubGateway {
            plan: Ok(private_plan(99)),
        };
        assert!(!access_allowed(&gateway, 2, 1));
    }
