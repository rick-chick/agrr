// Tests for `interactors/farm_update_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::entities::FarmEntity;
    use crate::farm::gateways::FarmGateway;
    use crate::farm::ports::{FarmUpdateOutputPort, UpdateFailure};
    use crate::shared::attr::AttrMap;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            String::new()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<FarmEntity>,
        failure: Option<UpdateFailure>,
    }

    impl FarmUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FarmEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn current_farm(user_id: i64) -> FarmEntity {
        FarmEntity {
            id: 5,
            name: "Old".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
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

    enum MockBehavior {
        Success {
            current: FarmEntity,
            updated: FarmEntity,
        },
        Denied(FarmEntity),
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
            match &self.behavior {
                MockBehavior::Success { current, .. } => Ok(current.clone()),
                MockBehavior::Denied(current) => Ok(current.clone()),
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
            match &self.behavior {
                MockBehavior::Success { updated, .. } => Ok(updated.clone()),
                MockBehavior::Denied(_) => unimplemented!("not called when edit denied"),
            }
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

    // Ruby: test "calls on_success when gateway returns entity"
    #[test]
    fn calls_on_success_when_gateway_returns_entity() {
        let current = current_farm(10);
        let updated = FarmEntity {
            name: "N".into(),
            ..current.clone()
        };
        let gateway = StubGateway {
            behavior: MockBehavior::Success {
                current,
                updated: updated.clone(),
            },
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = FarmUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor
            .call(FarmUpdateInput {
                farm_id: 5,
                name: Some("N".into()),
                region: None,
                latitude: None,
                longitude: None,
            })
            .expect("handled");
        assert_eq!(output.success, Some(updated));
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_when_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::Denied(current_farm(99)),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = FarmUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor
            .call(FarmUpdateInput {
                farm_id: 5,
                name: Some("N".into()),
                region: None,
                latitude: None,
                longitude: None,
            })
            .expect("handled");
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }
