//! Ruby: `Domain::WeatherData::Interactors::InternalFarmWeatherDataListInteractor`

use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::weather_data::dtos::{
    InternalFarmWeatherDataListResult, InternalFarmWeatherFetchFailure,
    InternalFarmWeatherHttpStatus, InternalFarmWeatherReadInput,
};
use crate::weather_data::gateways::InternalFarmWeatherReadGateway;
use crate::weather_data::ports::InternalFarmWeatherDataListOutputPort;

pub struct InternalFarmWeatherDataListInteractor<'a, G, O, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    translator: &'a T,
}

impl<'a, G, O, T> InternalFarmWeatherDataListInteractor<'a, G, O, T>
where
    G: InternalFarmWeatherReadGateway,
    O: InternalFarmWeatherDataListOutputPort,
    T: TranslatorPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, translator: &'a T) -> Self {
        Self {
            output_port,
            gateway,
            translator,
        }
    }

    pub fn call(&mut self, input: InternalFarmWeatherReadInput) {
        let farm_id = input.farm_id;
        match self.gateway.weather_data_list_snapshot(&farm_id) {
            InternalFarmWeatherDataListResult::FarmNotFound => {
                let opts = TranslateOptions::default();
                let message = self
                    .translator
                    .t("api.errors.common.farm_not_found", &opts);
                self.output_port.on_failure(InternalFarmWeatherFetchFailure {
                    message,
                    http_status: InternalFarmWeatherHttpStatus::NotFound,
                });
            }
            InternalFarmWeatherDataListResult::WeatherLocationNotFound => {
                let opts = TranslateOptions::default();
                let message = self
                    .translator
                    .t("api.errors.common.weather_location_not_found", &opts);
                self.output_port.on_failure(InternalFarmWeatherFetchFailure {
                    message,
                    http_status: InternalFarmWeatherHttpStatus::NotFound,
                });
            }
            InternalFarmWeatherDataListResult::Ok(success) => {
                self.output_port.on_success(success);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::weather_data::dtos::InternalFarmWeatherDataListOutput;
    use serde_json::json;

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            match key {
                "api.errors.common.farm_not_found" => "農場がありません".into(),
                "api.errors.common.weather_location_not_found" => "気象地点がありません".into(),
                _ => key.into(),
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<InternalFarmWeatherDataListOutput>,
        failure: Option<InternalFarmWeatherFetchFailure>,
    }

    impl InternalFarmWeatherDataListOutputPort for SpyOutput {
        fn on_success(&mut self, dto: InternalFarmWeatherDataListOutput) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure) {
            self.failure = Some(dto);
        }
    }

    struct StubGateway {
        result: InternalFarmWeatherDataListResult,
    }

    impl InternalFarmWeatherReadGateway for StubGateway {
        fn weather_data_list_snapshot(
            &self,
            farm_id: &str,
        ) -> InternalFarmWeatherDataListResult {
            assert_eq!(farm_id, "42");
            self.result.clone()
        }
        fn weather_status_snapshot(
            &self,
            _: &str,
        ) -> crate::weather_data::dtos::InternalFarmWeatherStatusResult {
            unimplemented!()
        }
    }

    // Ruby: test "farm_not_found delegates translated message and not_found status"
    #[test]
    fn farm_not_found_delegates_translated_message_and_not_found_status() {
        let gateway = StubGateway {
            result: InternalFarmWeatherDataListResult::farm_not_found(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let translator = StubTranslator;
        let mut interactor =
            InternalFarmWeatherDataListInteractor::new(&mut output, &gateway, &translator);

        interactor.call(InternalFarmWeatherReadInput {
            farm_id: "42".into(),
        });

        let failure = output.failure.expect("failure");
        assert_eq!(failure.message, "農場がありません");
        assert_eq!(failure.http_status, InternalFarmWeatherHttpStatus::NotFound);
    }

    // Ruby: test "weather_location_not_found delegates translated message"
    #[test]
    fn weather_location_not_found_delegates_translated_message() {
        let gateway = StubGateway {
            result: InternalFarmWeatherDataListResult::weather_location_not_found(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let translator = StubTranslator;
        let mut interactor =
            InternalFarmWeatherDataListInteractor::new(&mut output, &gateway, &translator);

        interactor.call(InternalFarmWeatherReadInput {
            farm_id: "42".into(),
        });

        let failure = output.failure.expect("failure");
        assert_eq!(failure.message, "気象地点がありません");
        assert_eq!(failure.http_status, InternalFarmWeatherHttpStatus::NotFound);
    }

    // Ruby: test "ok maps success dto to on_success"
    #[test]
    fn ok_maps_success_dto_to_on_success() {
        let success = InternalFarmWeatherDataListOutput {
            farm_summary: json!({ "id": 42 }),
            weather_location_summary: json!({ "id": 1 }),
            weather_data_rows: vec![],
            count: 0,
        };
        let gateway = StubGateway {
            result: InternalFarmWeatherDataListResult::ok(success.clone()),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let translator = StubTranslator;
        let mut interactor =
            InternalFarmWeatherDataListInteractor::new(&mut output, &gateway, &translator);

        interactor.call(InternalFarmWeatherReadInput {
            farm_id: "42".into(),
        });

        assert_eq!(output.success.as_ref(), Some(&success));
    }
}
