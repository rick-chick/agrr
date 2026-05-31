// Tests for `interactors/farm_list_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::entities::FarmEntity;
    use crate::farm::gateways::FarmGateway;
    use crate::farm::ports::FarmListOutputPort;
    
    

    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct SpyOutput {
        success: Option<FarmListSuccess>,
        failure: Option<ListFailure>,
    }

    impl FarmListOutputPort for SpyOutput {
        fn on_success(&mut self, result: FarmListSuccess) {
            self.success = Some(result);
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_farm(id: i64) -> FarmEntity {
        FarmEntity {
            id,
            name: format!("Farm {id}"),
            latitude: None,
            longitude: None,
            region: None,
            user_id: Some(1),
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

    enum MockBehavior {
        Regular(Vec<FarmEntity>),
        Admin {
            list: Vec<FarmEntity>,
            reference: Vec<FarmEntity>,
        },
        PolicyDenied,
    }

    struct StubGateway {
        behavior: MockBehavior,
    }

    impl FarmGateway for StubGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Regular(farms) => Ok(farms.clone()),
                MockBehavior::PolicyDenied => Err(Box::new(PolicyPermissionDenied)),
                MockBehavior::Admin { .. } => unimplemented!(),
            }
        }

        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Admin { list, .. } => Ok(list.clone()),
                _ => unimplemented!(),
            }
        }

        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockBehavior::Admin { reference, .. } => Ok(reference.clone()),
                _ => unimplemented!(),
            }
        }
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
            unimplemented!()
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

    // Ruby: test "calls list_user_owned_farms and on_success with empty reference_farms for regular user"
    #[test]
    fn calls_list_user_owned_for_regular_user() {
        let farms = vec![sample_farm(1)];
        let gateway = StubGateway {
            behavior: MockBehavior::Regular(farms.clone()),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FarmListInteractor::new(&mut output, 1, &gateway);
        interactor
            .call(Some(FarmListInput::regular_user()))
            .expect("handled");
        let success = output.success.expect("success");
        assert_eq!(success.farms, farms);
        assert!(success.reference_farms.is_empty());
    }

    // Ruby: test "calls list_user_and_reference_farms and list_reference_farms for admin"
    #[test]
    fn calls_list_user_and_reference_for_admin() {
        let list = vec![sample_farm(1)];
        let reference = vec![sample_farm(99)];
        let gateway = StubGateway {
            behavior: MockBehavior::Admin {
                list: list.clone(),
                reference: reference.clone(),
            },
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FarmListInteractor::new(&mut output, 2, &gateway);
        interactor
            .call(Some(FarmListInput::new(true)))
            .expect("handled");
        let success = output.success.expect("success");
        assert_eq!(success.farms, list);
        assert_eq!(success.reference_farms, reference);
    }

    // Ruby: test "forwards policy permission denied to on_failure as exception"
    #[test]
    fn forwards_policy_permission_denied_to_on_failure() {
        let gateway = StubGateway {
            behavior: MockBehavior::PolicyDenied,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FarmListInteractor::new(&mut output, 1, &gateway);
        interactor
            .call(Some(FarmListInput::regular_user()))
            .expect("handled");
        assert!(matches!(
            output.failure,
            Some(ListFailure::Policy(PolicyPermissionDenied))
        ));
    }
