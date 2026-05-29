// Tests for `interactors/farm_list_reference_for_region_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::shared::attr::AttrMap;
    use crate::shared::exceptions::RecordInvalidError;
    use crate::shared::user::User;

    struct SpyOutput {
        success: Option<Vec<FarmEntity>>,
        failure: Option<Error>,
    }

    impl FarmListReferenceForRegionOutputPort for SpyOutput {
        fn on_success(&mut self, farms: Vec<FarmEntity>) {
            self.success = Some(farms);
        }
        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    struct StubLogger;
    impl crate::shared::ports::logger_port::LoggerPort for StubLogger {
        fn debug(&self, _: &str) {}
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
    }

    struct OkGateway {
        farms: Vec<FarmEntity>,
    }

    impl FarmGateway for OkGateway {
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


        fn update_weather_progress(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::farm::entities::FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms_for_region(
            &self,
            region: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(region, "jp");
            Ok(self.farms.clone())
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

    struct InvalidGateway;

    impl FarmGateway for InvalidGateway {
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
            region: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(region, "us");
            Err(Box::new(RecordInvalidError::new(Some("invalid region".into()), None)))
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

    fn sample_farm(id: i64) -> FarmEntity {
        FarmEntity {
            id,
            name: format!("Farm {id}"),
            latitude: None,
            longitude: None,
            region: Some("jp".into()),
            user_id: None,
            created_at: None,
            updated_at: None,
            is_reference: true,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    // Ruby: test "on_success with reference farms for region"
    #[test]
    fn on_success_with_reference_farms_for_region() {
        let farms = vec![sample_farm(1), sample_farm(2)];
        let gateway = OkGateway {
            farms: farms.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let logger = StubLogger;
        let mut interactor =
            FarmListReferenceForRegionInteractor::new(&mut output, &gateway, &logger);

        interactor.call("jp").unwrap();

        assert_eq!(output.success.as_ref(), Some(&farms));
        assert!(output.failure.is_none());
    }

    // Ruby: test "on_failure when gateway raises RecordInvalid"
    #[test]
    fn on_failure_when_gateway_raises_record_invalid() {
        let gateway = InvalidGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let logger = StubLogger;
        let mut interactor =
            FarmListReferenceForRegionInteractor::new(&mut output, &gateway, &logger);

        interactor.call("us").unwrap();

        assert!(output.success.is_none());
        assert_eq!(
            output.failure.as_ref().map(|e| e.message.as_str()),
            Some("invalid region")
        );
    }
