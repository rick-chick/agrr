//! Ruby: `Domain::WeatherData::Interactors::InternalWeatherFetchStartInteractor`

use std::collections::BTreeMap;

use crate::shared::ports::TranslatorPort;
use crate::weather_data::dtos::{
    InternalWeatherFetchFailure, InternalWeatherFetchHttpStatus, InternalWeatherFetchStartInput,
    InternalWeatherFetchStartOutput, InternalWeatherFetchStartVariant,
};
use crate::weather_data::gateways::{
    InternalWeatherFetchStartGateway, StartFarmWeatherDataFetchPort,
    StartInternalWeatherFetchResult, WeatherFetchFarmSnapshot,
};
use crate::weather_data::ports::InternalWeatherFetchStartOutputPort;

/// Ruby: `Domain::WeatherData::Interactors::InternalWeatherFetchStartInteractor`
pub struct InternalWeatherFetchStartInteractor<'a, O, T> {
    output_port: &'a mut O,
    gateway: &'a dyn InternalWeatherFetchStartGateway,
    translator: &'a T,
    start_farm_weather_data_fetch: &'a dyn StartFarmWeatherDataFetchPort,
    calendar_today: time::Date,
}

impl<'a, O, T> InternalWeatherFetchStartInteractor<'a, O, T>
where
    O: InternalWeatherFetchStartOutputPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a dyn InternalWeatherFetchStartGateway,
        translator: &'a T,
        start_farm_weather_data_fetch: &'a dyn StartFarmWeatherDataFetchPort,
        calendar_today: time::Date,
    ) -> Self {
        Self {
            output_port,
            gateway,
            translator,
            start_farm_weather_data_fetch,
            calendar_today,
        }
    }

    pub fn call(&mut self, input: InternalWeatherFetchStartInput) {
        match self
            .gateway
            .start_internal_weather_data_fetch(&input.farm_id)
        {
            StartInternalWeatherFetchResult::FarmNotFound => {
                let message = self
                    .translator
                    .t("api.errors.common.farm_not_found", &BTreeMap::new());
                self.output_port.on_failure(InternalWeatherFetchFailure {
                    message,
                    http_status: InternalWeatherFetchHttpStatus::NotFound,
                });
            }
            StartInternalWeatherFetchResult::Completed(snap) => {
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::AlreadyCompleted));
            }
            StartInternalWeatherFetchResult::Started(snap) => {
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::FetchStarted));
            }
            StartInternalWeatherFetchResult::NeedsFetch(snap) => {
                let started = self
                    .start_farm_weather_data_fetch
                    .call(snap.farm_id, self.calendar_today);
                let snap = WeatherFetchFarmSnapshot {
                    farm_id: snap.farm_id,
                    weather_data_status: started
                        .as_ref()
                        .map(|s| s.weather_data_status.clone())
                        .unwrap_or_else(|| "fetching".to_string()),
                    weather_data_count: snap.weather_data_count,
                    total_blocks: started
                        .map(|s| s.weather_data_total_years)
                        .unwrap_or(snap.total_blocks),
                };
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::FetchStarted));
            }
            StartInternalWeatherFetchResult::Failed(message) => {
                self.output_port.on_failure(InternalWeatherFetchFailure {
                    message,
                    http_status: InternalWeatherFetchHttpStatus::InternalServerError,
                });
            }
        }
    }
}

fn map_success(
    snap: WeatherFetchFarmSnapshot,
    variant: InternalWeatherFetchStartVariant,
) -> InternalWeatherFetchStartOutput {
    InternalWeatherFetchStartOutput {
        variant,
        farm_id: snap.farm_id,
        weather_data_status: snap.weather_data_status,
        weather_data_count: snap.weather_data_count,
        total_blocks: snap.total_blocks,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::weather_data::gateways::StartedFarmWeatherFetchSnapshot;
    use std::sync::{Arc, Mutex};
    use time::{Date, Month};

    struct RecordingOutput {
        success: Arc<Mutex<Option<InternalWeatherFetchStartOutput>>>,
        failure: Arc<Mutex<Option<InternalWeatherFetchFailure>>>,
    }

    impl InternalWeatherFetchStartOutputPort for RecordingOutput {
        fn on_success(&mut self, dto: InternalWeatherFetchStartOutput) {
            *self.success.lock().expect("lock") = Some(dto);
        }

        fn on_failure(&mut self, dto: InternalWeatherFetchFailure) {
            *self.failure.lock().expect("lock") = Some(dto);
        }
    }

    struct MockGateway {
        result: StartInternalWeatherFetchResult,
    }

    impl InternalWeatherFetchStartGateway for MockGateway {
        fn start_internal_weather_data_fetch(
            &self,
            _: &str,
        ) -> StartInternalWeatherFetchResult {
            match &self.result {
                StartInternalWeatherFetchResult::FarmNotFound => {
                    StartInternalWeatherFetchResult::FarmNotFound
                }
                StartInternalWeatherFetchResult::Completed(s) => {
                    StartInternalWeatherFetchResult::Completed(s.clone())
                }
                StartInternalWeatherFetchResult::Started(s) => {
                    StartInternalWeatherFetchResult::Started(s.clone())
                }
                StartInternalWeatherFetchResult::NeedsFetch(s) => {
                    StartInternalWeatherFetchResult::NeedsFetch(s.clone())
                }
                StartInternalWeatherFetchResult::Failed(m) => {
                    StartInternalWeatherFetchResult::Failed(m.clone())
                }
            }
        }
    }

    struct MockTranslator;
    impl TranslatorPort for MockTranslator {
        fn translate(&self, key: &str, _: &BTreeMap<String, String>) -> String {
            if key == "api.errors.common.farm_not_found" {
                "農場がありません".into()
            } else {
                key.into()
            }
        }

        fn localize(
            &self,
            _: Date,
            _: Option<&str>,
            _: &BTreeMap<String, String>,
        ) -> String {
            String::new()
        }
    }

    struct NoopStartFetch;
    impl StartFarmWeatherDataFetchPort for NoopStartFetch {
        fn call(&self, _: i64, _: Date) -> Option<StartedFarmWeatherFetchSnapshot> {
            None
        }
    }

    #[test]
    fn farm_not_found_delegates_translated_message_and_not_found_status() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = RecordingOutput {
            success: success.clone(),
            failure: failure.clone(),
        };
        let gateway = MockGateway {
            result: StartInternalWeatherFetchResult::FarmNotFound,
        };
        let translator = MockTranslator;
        let start_fetch = NoopStartFetch;
        let calendar_today = Date::from_calendar_date(2026, Month::January, 1).expect("valid");
        let mut interactor = InternalWeatherFetchStartInteractor::new(
            &mut output,
            &gateway,
            &translator,
            &start_fetch,
            calendar_today,
        );

        interactor.call(InternalWeatherFetchStartInput {
            farm_id: "42".into(),
        });

        let dto = failure.lock().expect("lock").clone().expect("failure");
        assert_eq!(dto.message, "農場がありません");
        assert_eq!(dto.http_status, InternalWeatherFetchHttpStatus::NotFound);
    }

    #[test]
    fn completed_maps_snapshot_to_success_dto() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = RecordingOutput {
            success: success.clone(),
            failure: failure.clone(),
        };
        let snap = WeatherFetchFarmSnapshot {
            farm_id: 42,
            weather_data_status: "completed".into(),
            weather_data_count: Some(3),
            total_blocks: 10,
        };
        let gateway = MockGateway {
            result: StartInternalWeatherFetchResult::Completed(snap),
        };
        let translator = MockTranslator;
        let start_fetch = NoopStartFetch;
        let calendar_today = Date::from_calendar_date(2026, Month::January, 1).expect("valid");
        let mut interactor = InternalWeatherFetchStartInteractor::new(
            &mut output,
            &gateway,
            &translator,
            &start_fetch,
            calendar_today,
        );

        interactor.call(InternalWeatherFetchStartInput {
            farm_id: "42".into(),
        });

        let dto = success.lock().expect("lock").clone().expect("success");
        assert_eq!(dto.variant, InternalWeatherFetchStartVariant::AlreadyCompleted);
        assert_eq!(dto.farm_id, 42);
        assert_eq!(dto.weather_data_status, "completed");
        assert_eq!(dto.weather_data_count, Some(3));
        assert_eq!(dto.total_blocks, 10);
    }

    #[test]
    fn started_maps_snapshot_to_success_dto() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = RecordingOutput {
            success: success.clone(),
            failure: failure.clone(),
        };
        let snap = WeatherFetchFarmSnapshot {
            farm_id: 42,
            weather_data_status: "pending".into(),
            weather_data_count: None,
            total_blocks: 5,
        };
        let gateway = MockGateway {
            result: StartInternalWeatherFetchResult::Started(snap),
        };
        let translator = MockTranslator;
        let start_fetch = NoopStartFetch;
        let calendar_today = Date::from_calendar_date(2026, Month::January, 1).expect("valid");
        let mut interactor = InternalWeatherFetchStartInteractor::new(
            &mut output,
            &gateway,
            &translator,
            &start_fetch,
            calendar_today,
        );

        interactor.call(InternalWeatherFetchStartInput {
            farm_id: "42".into(),
        });

        let dto = success.lock().expect("lock").clone().expect("success");
        assert_eq!(dto.variant, InternalWeatherFetchStartVariant::FetchStarted);
        assert_eq!(dto.farm_id, 42);
        assert_eq!(dto.weather_data_status, "pending");
        assert_eq!(dto.weather_data_count, None);
        assert_eq!(dto.total_blocks, 5);
    }

    #[test]
    fn failed_maps_error_message_to_internal_server_error() {
        let success = Arc::new(Mutex::new(None));
        let failure = Arc::new(Mutex::new(None));
        let mut output = RecordingOutput {
            success: success.clone(),
            failure: failure.clone(),
        };
        let gateway = MockGateway {
            result: StartInternalWeatherFetchResult::Failed("enqueue blew up".into()),
        };
        let translator = MockTranslator;
        let start_fetch = NoopStartFetch;
        let calendar_today = Date::from_calendar_date(2026, Month::January, 1).expect("valid");
        let mut interactor = InternalWeatherFetchStartInteractor::new(
            &mut output,
            &gateway,
            &translator,
            &start_fetch,
            calendar_today,
        );

        interactor.call(InternalWeatherFetchStartInput {
            farm_id: "42".into(),
        });

        let dto = failure.lock().expect("lock").clone().expect("failure");
        assert_eq!(dto.message, "enqueue blew up");
        assert_eq!(
            dto.http_status,
            InternalWeatherFetchHttpStatus::InternalServerError
        );
    }
}
