// Tests for `interactors/farm_detail_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::dtos::FarmDetailOutput;
    use crate::farm::entities::FarmEntity;
    use crate::farm::gateways::FarmGateway;
    use crate::farm::ports::{DetailFailure, FarmDetailOutputPort};
    use crate::shared::gateways::UserLookupGateway;
    

    use crate::farm::entities::FieldEntity;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct SpyOutput {
        success: Option<FarmDetailOutput>,
        failure: Option<DetailFailure>,
    }

    impl FarmDetailOutputPort for SpyOutput {
        fn on_success(&mut self, output: FarmDetailOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    fn farm_entity(user_id: i64) -> FarmEntity {
        FarmEntity {
            id: 3,
            name: "F".into(),
            latitude: None,
            longitude: None,
            region: None,
            user_id: Some(user_id),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    fn detail_dto() -> FarmDetailOutput {
        FarmDetailOutput::new(
            farm_entity(10),
            vec![FieldEntity {
                id: 1,
                name: "Field".into(),
                area: None,
                daily_fixed_cost: None,
                region: None,
                farm_id: 3,
                user_id: Some(10),
                created_at: None,
                updated_at: None,
            }],
        )
    }

    enum MockBehavior {
        Success,
        Denied,
    }

    struct StubGateway {
        behavior: MockBehavior,
    }

    impl FarmGateway for StubGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            match self.behavior {
                MockBehavior::Success => Ok(farm_entity(10)),
                MockBehavior::Denied => Ok(farm_entity(99)),
            }
        }
        fn update_weather_progress(
            &self,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>
        {
            match self.behavior {
                MockBehavior::Success => Ok(detail_dto()),
                MockBehavior::Denied => unimplemented!("not called when view denied"),
            }
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    // Ruby: test "calls on_success when read gateway returns wire"
    #[test]
    fn calls_on_success_when_gateway_returns_detail() {
        let gateway = StubGateway {
            behavior: MockBehavior::Success,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor =
            FarmDetailInteractor::new(&mut output, 10, &gateway, &user_lookup);
        interactor.call(3).expect("handled");
        let detail = output.success.expect("success");
        assert_eq!(detail.farm.id, 3);
        assert_eq!(detail.fields.len(), 1);
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_when_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::Denied,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor =
            FarmDetailInteractor::new(&mut output, 10, &gateway, &user_lookup);
        interactor.call(3).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }
