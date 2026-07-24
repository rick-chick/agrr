// Tests for `interactors/farm_create_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::entities::FarmEntity;
    use crate::farm::gateways::FarmGateway;
    use crate::farm::ports::{CreateFailure, FarmCreateOutputPort};
    use crate::shared::attr::AttrMap;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
    use crate::shared::ports::ClockPort;
    use crate::weather_data::gateways::{
        StartFarmWeatherDataFetchPort, StartedFarmWeatherFetchSnapshot,
    };
    use std::sync::Mutex;
    use time::{Date, Month, OffsetDateTime};

    use crate::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FixedClock;
    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            Date::from_calendar_date(2026, Month::July, 23).unwrap()
        }
        fn now(&self) -> OffsetDateTime {
            OffsetDateTime::now_utc()
        }
    }

    struct NoopStartWeatherFetch;
    impl StartFarmWeatherDataFetchPort for NoopStartWeatherFetch {
        fn call(&self, _: i64, _: Date) -> Option<StartedFarmWeatherFetchSnapshot> {
            None
        }
    }

    struct SpyStartWeatherFetch {
        calls: Mutex<Vec<i64>>,
    }

    impl StartFarmWeatherDataFetchPort for SpyStartWeatherFetch {
        fn call(&self, farm_id: i64, _: Date) -> Option<StartedFarmWeatherFetchSnapshot> {
            self.calls.lock().unwrap().push(farm_id);
            Some(StartedFarmWeatherFetchSnapshot {
                weather_data_status: "fetching".into(),
                weather_data_total_years: 6,
            })
        }
    }

    struct SpyOutput {
        success: Option<FarmEntity>,
        failure: Option<CreateFailure>,
    }

    impl FarmCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FarmEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_farm() -> FarmEntity {
        FarmEntity {
            id: 99,
            name: "新規農場".into(),
            latitude: Some(35.0),
            longitude: Some(135.0),
            region: None,
            user_id: Some(10),
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

    struct UnderLimitGateway {
        count: i32,
        entity: FarmEntity,
    }

    struct AtLimitGateway;

    impl FarmGateway for UnderLimitGateway {
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
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.count)
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
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
        ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
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

    impl FarmGateway for AtLimitGateway {
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
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(4)
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
        ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
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

    // Ruby: test "calls on_success when under farm limit"
    #[test]
    fn calls_on_success_when_under_farm_limit() {
        let entity = sample_farm();
        let gateway = UnderLimitGateway {
            count: 3,
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let weather_fetch = NoopStartWeatherFetch;
        let clock = FixedClock;
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &weather_fetch,
            &clock,
        );
        interactor
            .call(FarmCreateInput::new(
                "新規農場",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();
        assert_eq!(output.success, Some(entity));
    }

    #[test]
    fn does_not_start_weather_fetch_without_coordinates() {
        let entity = FarmEntity {
            latitude: None,
            longitude: None,
            ..sample_farm()
        };
        let gateway = UnderLimitGateway {
            count: 3,
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let weather_fetch = SpyStartWeatherFetch {
            calls: Mutex::new(Vec::new()),
        };
        let clock = FixedClock;
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &weather_fetch,
            &clock,
        );
        interactor
            .call(FarmCreateInput::new("座標なし農場", None, None, None))
            .unwrap();
        assert!(weather_fetch.calls.lock().unwrap().is_empty());
        let success = output.success.expect("success");
        assert!(success.weather_data_status.is_none());
        assert!(success.weather_data_total_years.is_none());
    }

    #[test]
    fn starts_weather_fetch_after_create_with_coordinates() {
        let entity = sample_farm();
        let gateway = UnderLimitGateway {
            count: 3,
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let weather_fetch = SpyStartWeatherFetch {
            calls: Mutex::new(Vec::new()),
        };
        let clock = FixedClock;
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &weather_fetch,
            &clock,
        );
        interactor
            .call(FarmCreateInput::new(
                "新規農場",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();
        assert_eq!(weather_fetch.calls.lock().unwrap().as_slice(), &[99]);
        let success = output.success.expect("success");
        assert_eq!(success.weather_data_status.as_deref(), Some("fetching"));
        assert_eq!(success.weather_data_total_years, Some(6));
        assert_eq!(success.weather_data_fetched_years, Some(0));
    }

    // Ruby: test "calls on_failure with limit exceeded dto when at farm limit"
    #[test]
    fn calls_on_failure_with_limit_exceeded_when_at_farm_limit() {
        let gateway = AtLimitGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let weather_fetch = NoopStartWeatherFetch;
        let clock = FixedClock;
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &weather_fetch,
            &clock,
        );
        interactor
            .call(FarmCreateInput::new(
                "5件目",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();
        match output.failure {
            Some(CreateFailure::LimitExceeded(dto)) => {
                assert_eq!(
                    dto.message,
                    "t:activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"
                );
            }
            other => panic!("expected LimitExceeded failure, got {other:?}"),
        }
    }
