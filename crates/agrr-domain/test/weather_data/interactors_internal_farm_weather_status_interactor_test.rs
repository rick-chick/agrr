// Tests for `interactors/internal_farm_weather_status_interactor.rs` (Ruby parity under test/domain/weather_data/).

    use crate::weather_data::dtos::InternalFarmWeatherStatusOutput;

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            if key == "api.errors.common.farm_not_found" {
                "農場がありません".into()
            } else {
                key.into()
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<InternalFarmWeatherStatusOutput>,
        failure: Option<InternalFarmWeatherFetchFailure>,
    }

    impl InternalFarmWeatherStatusOutputPort for SpyOutput {
        fn on_success(&mut self, dto: InternalFarmWeatherStatusOutput) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure) {
            self.failure = Some(dto);
        }
    }

    struct StubGateway {
        result: InternalFarmWeatherStatusResult,
    }

    impl InternalFarmWeatherReadGateway for StubGateway {
        fn weather_data_list_snapshot(
            &self,
            _: &str,
        ) -> crate::weather_data::dtos::InternalFarmWeatherDataListResult {
            unimplemented!()
        }
        fn weather_status_snapshot(
            &self,
            farm_id: &str,
        ) -> InternalFarmWeatherStatusResult {
            assert_eq!(farm_id, "99");
            self.result.clone()
        }
    }

    // Ruby: test "farm_not_found delegates translated message and not_found status"
    #[test]
    fn farm_not_found_delegates_translated_message_and_not_found_status() {
        let gateway = StubGateway {
            result: InternalFarmWeatherStatusResult::farm_not_found(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let translator = StubTranslator;
        let mut interactor =
            InternalFarmWeatherStatusInteractor::new(&mut output, &gateway, &translator);

        interactor.call(InternalFarmWeatherReadInput {
            farm_id: "99".into(),
        });

        let failure = output.failure.expect("failure");
        assert_eq!(failure.message, "農場がありません");
        assert_eq!(failure.http_status, InternalFarmWeatherHttpStatus::NotFound);
    }

    // Ruby: test "ok maps status snapshot to on_success"
    #[test]
    fn ok_maps_status_snapshot_to_on_success() {
        let success = InternalFarmWeatherStatusOutput {
            farm_id: 99,
            status: "completed".into(),
            progress: 100,
            fetched_blocks: 5,
            total_blocks: 5,
            weather_data_count: 120,
            last_error: None,
        };
        let gateway = StubGateway {
            result: InternalFarmWeatherStatusResult::ok(success.clone()),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let translator = StubTranslator;
        let mut interactor =
            InternalFarmWeatherStatusInteractor::new(&mut output, &gateway, &translator);

        interactor.call(InternalFarmWeatherReadInput {
            farm_id: "99".into(),
        });

        assert_eq!(output.success.as_ref(), Some(&success));
    }
