// Tests for `interactors/farm_create_interactor.rs` (Ruby parity under test/domain/farm/).

    use crate::farm::entities::FarmEntity;
    use crate::farm::gateways::FarmGateway;
    use crate::farm::ports::{CreateFailure, FarmCreateOutputPort};
    use crate::shared::attr::{AttrMap, AttrValue};
    use crate::shared::dtos::WeatherFetchDateBlock;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
    use crate::shared::ports::{ClockPort, FetchWeatherDataEnqueuePort};
    use std::sync::Mutex;
    use time::macros::date;
    use time::{Date, OffsetDateTime};

    use crate::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            date!(2026 - 07 - 23)
        }
        fn now(&self) -> OffsetDateTime {
            OffsetDateTime::UNIX_EPOCH
        }
    }

    struct SpyEnqueue {
        calls: Mutex<Vec<(i64, f64, f64, usize)>>,
    }

    impl FetchWeatherDataEnqueuePort for SpyEnqueue {
        fn enqueue_farm_weather_fetch(
            &self,
            farm_id: i64,
            latitude: f64,
            longitude: f64,
            blocks: &[WeatherFetchDateBlock],
        ) {
            self.calls
                .lock()
                .unwrap()
                .push((farm_id, latitude, longitude, blocks.len()));
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
        updated_attrs: Mutex<Option<AttrMap>>,
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
            farm_id: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(farm_id, self.entity.id);
            let mut farm = self.entity.clone();
            if let Some(attrs) = self.updated_attrs.lock().unwrap().clone() {
                if let Some(AttrValue::Str(status)) = attrs.get("weather_data_status") {
                    farm.weather_data_status = Some(status.clone());
                }
                if let Some(AttrValue::Int(total)) = attrs.get("weather_data_total_years") {
                    farm.weather_data_total_years = Some(*total as i32);
                }
            }
            Ok(farm)
        }

        fn update_weather_progress(
            &self,
            farm_id: i64,
            attrs: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(farm_id, self.entity.id);
            *self.updated_attrs.lock().unwrap() = Some(attrs);
            self.find_by_id(farm_id)
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
            updated_attrs: Mutex::new(None),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let enqueue = SpyEnqueue {
            calls: Mutex::new(Vec::new()),
        };
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &enqueue,
            &FakeClock,
        );
        interactor
            .call(FarmCreateInput::new(
                "新規農場",
                None,
                None,
                None,
            ))
            .unwrap();
        assert_eq!(output.success, Some(entity));
        assert!(enqueue.calls.lock().unwrap().is_empty());
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
        let enqueue = SpyEnqueue {
            calls: Mutex::new(Vec::new()),
        };
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &enqueue,
            &FakeClock,
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

    // Issue #462: farm create with coordinates starts weather fetch enqueue
    #[test]
    fn starts_weather_fetch_after_successful_create_with_coordinates() {
        let entity = sample_farm();
        let gateway = UnderLimitGateway {
            count: 3,
            entity: entity.clone(),
            updated_attrs: Mutex::new(None),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let enqueue = SpyEnqueue {
            calls: Mutex::new(Vec::new()),
        };
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
            &enqueue,
            &FakeClock,
        );
        interactor
            .call(FarmCreateInput::new(
                "新規農場",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();

        let success = output.success.expect("expected success");
        assert_eq!(Some("fetching"), success.weather_data_status.as_deref());
        assert!(success.weather_data_total_years.unwrap_or(0) > 0);

        let calls = enqueue.calls.lock().unwrap();
        assert_eq!(1, calls.len());
        assert_eq!(99, calls[0].0);
        assert_eq!(35.0, calls[0].1);
        assert_eq!(135.0, calls[0].2);
        assert!(calls[0].3 > 0);
    }
