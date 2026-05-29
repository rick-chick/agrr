// Tests for `interactors/farm_destroy_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::dtos::FarmDeleteUsage;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, options: &TranslateOptions) -> String {
            if key == "farms.flash.cannot_delete" {
                return format!(
                    "blocked:{}",
                    options.get("count").map(String::as_str).unwrap_or("?")
                );
            }
            if key == "flash.farms.deleted" {
                return format!(
                    "toast:{}",
                    options.get("name").map(String::as_str).unwrap_or("?")
                );
            }
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<FarmDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl FarmDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, output: FarmDestroyOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    fn farm_entity(user_id: i64, name: &str) -> FarmEntity {
        FarmEntity {
            id: 5,
            name: name.into(),
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

    enum MockBehavior {
        Success,
        BlockedByCropPlans,
        Denied,
    }

    struct StubGateway {
        behavior: MockBehavior,
        user_id: i64,
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
            Ok(farm_entity(self.user_id, "Test Farm"))
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
            let count = match self.behavior {
                MockBehavior::Success => 0,
                MockBehavior::BlockedByCropPlans => 3,
                MockBehavior::Denied => 0,
            };
            Ok(FarmDeleteUsage::new(count))
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
            match self.behavior {
                MockBehavior::Success => Ok(SoftDeleteWithUndoOutcome::Success {
                    undo: serde_json::json!({ "expires_at": "2026-01-01T00:05:00Z" }),
                    farm_name: "Test Farm".into(),
                }),
                _ => unimplemented!(),
            }
        }
    }

    // Ruby: test "should destroy farm successfully when no crop plans exist"
    #[test]
    fn destroys_farm_when_no_crop_plans_exist() {
        let gateway = StubGateway {
            behavior: MockBehavior::Success,
            user_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(5).unwrap();
        assert!(output.success.is_some());
        assert_eq!(output.success.as_ref().unwrap().farm_name, "Test Farm");
    }

    // Ruby: test "calls on_failure when free crop plans block delete"
    #[test]
    fn calls_on_failure_when_free_crop_plans_block_delete() {
        let gateway = StubGateway {
            behavior: MockBehavior::BlockedByCropPlans,
            user_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        match output.failure {
            Some(DestroyFailure::Error(e)) => assert_eq!(e.message, "blocked:3"),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }

    // Ruby: test "calls on_failure when policy permission denied"
    #[test]
    fn calls_on_failure_when_policy_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::Denied,
            user_id: 99,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(1, false));
        let mut interactor = FarmDestroyInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(1).unwrap();
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
