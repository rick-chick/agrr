//! Ruby: `Domain::PublicPlan::Interactors::EntryScheduleShowInteractor`

use std::collections::BTreeMap;

use serde_json::Value;
use time::Date;

use crate::public_plan::dtos::{EntryScheduleFailure, EntryScheduleShowOutput};
use crate::public_plan::exceptions::{
    PredictionPayloadMissingError, WeatherLocationMissingError, WeatherPredictionFailedError,
};
use crate::public_plan::mappers::entry_schedule_crop_mapper::{
    self, EntryScheduleCropLike, EntryScheduleFarmLike, EntryScheduleWindowResult,
};
use crate::public_plan::ports::{EntryScheduleCropGateway, EntryScheduleShowOutputPort};
use crate::shared::ports::{ClockPort, TranslatorPort};

/// Weather payload loader (Ruby: `@weather_loader`).
pub trait EntryScheduleWeatherLoaderPort: Send + Sync {
    fn load_prediction_payload(
        &self,
        farm: &dyn EntryScheduleShowFarm,
        prediction_end_date_raw: Option<&str>,
        reference_date: Date,
    ) -> Result<BTreeMap<String, Value>, Box<dyn std::error::Error + Send + Sync>>;
}

/// Optimization runner (Ruby: `@optimization_runner`).
pub trait EntryScheduleOptimizationRunnerPort: Send + Sync {
    fn call(
        &self,
        crop: &dyn EntryScheduleShowCrop,
        weather_payload: &BTreeMap<String, Value>,
        farm: &dyn EntryScheduleShowFarm,
    ) -> EntryScheduleWindowResult;
}

/// Farm input for entry schedule show.
pub trait EntryScheduleShowFarm: EntryScheduleFarmLike {
    fn id(&self) -> i64;
    fn name(&self) -> &str;
    fn latitude(&self) -> f64;
    fn longitude(&self) -> f64;
    fn region(&self) -> &str;
}

/// Crop input for entry schedule show.
pub trait EntryScheduleShowCrop: EntryScheduleCropLike {}

/// Ruby: `Domain::PublicPlan::Interactors::EntryScheduleShowInteractor`
pub struct EntryScheduleShowInteractor<'a, O, CG, W, R, T, C> {
    output_port: &'a mut O,
    crop_gateway: &'a CG,
    weather_loader: &'a W,
    optimization_runner: &'a R,
    translator: &'a T,
    clock: &'a C,
}

impl<'a, O, CG, W, R, T, C> EntryScheduleShowInteractor<'a, O, CG, W, R, T, C>
where
    O: EntryScheduleShowOutputPort,
    CG: EntryScheduleCropGateway,
    W: EntryScheduleWeatherLoaderPort,
    R: EntryScheduleOptimizationRunnerPort,
    T: TranslatorPort,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a CG,
        weather_loader: &'a W,
        optimization_runner: &'a R,
        translator: &'a T,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            weather_loader,
            optimization_runner,
            translator,
            clock,
        }
    }

    /// Ruby: `#call(farm:, crop:, reference_date:, prediction_end_date_raw:)`
    pub fn call(
        &mut self,
        farm: &dyn EntryScheduleShowFarm,
        crop: &dyn EntryScheduleShowCrop,
        reference_date: Date,
        prediction_end_date_raw: Option<&str>,
    ) {
        let payload_hash = match self.weather_loader.load_prediction_payload(
            farm,
            prediction_end_date_raw,
            reference_date,
        ) {
            Ok(hash) => hash,
            Err(err) => {
                if err.downcast_ref::<WeatherLocationMissingError>().is_some() {
                    self.output_port
                        .on_failure(EntryScheduleFailure::weather_location_required());
                } else if err.downcast_ref::<PredictionPayloadMissingError>().is_some() {
                    self.output_port
                        .on_failure(EntryScheduleFailure::prediction_payload_missing());
                } else if let Some(e) = err.downcast_ref::<WeatherPredictionFailedError>() {
                    self.output_port.on_failure(
                        EntryScheduleFailure::weather_prediction_failed(e.0.clone()),
                    );
                } else {
                    self.output_port
                        .on_failure(EntryScheduleFailure::internal_error(err.to_string()));
                }
                return;
            }
        };

        let result = self
            .optimization_runner
            .call(crop, &payload_hash, farm);
        let crop_stages = self.crop_gateway.list_by_crop_id(crop.id());
        let crop_detail = entry_schedule_crop_mapper::crop_detail(
            crop,
            &result,
            self.translator,
            &crop_stages,
            self.clock,
        );
        let prediction_meta = entry_schedule_crop_mapper::prediction_meta(
            farm,
            &payload_hash,
            reference_date.year(),
        );

        let mut farm_fragment = BTreeMap::new();
        farm_fragment.insert("id".into(), Value::from(farm.id()));
        farm_fragment.insert("name".into(), Value::from(farm.name()));
        farm_fragment.insert("latitude".into(), Value::from(farm.latitude()));
        farm_fragment.insert("longitude".into(), Value::from(farm.longitude()));
        farm_fragment.insert("region".into(), Value::from(farm.region()));

        self.output_port.on_success(EntryScheduleShowOutput::new(
            farm_fragment,
            prediction_meta,
            crop_detail,
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::public_plan::mappers::entry_schedule_crop_mapper::CropStageRow;
    use crate::shared::ports::TranslateOptions;
    use serde_json::json;
    use std::collections::BTreeMap;
    use time::Month;

    struct TestFarm {
        id: i64,
        weather_location_id: i64,
    }

    impl EntryScheduleFarmLike for TestFarm {
        fn weather_location_id(&self) -> Option<i64> {
            Some(self.weather_location_id)
        }
    }

    impl EntryScheduleShowFarm for TestFarm {
        fn id(&self) -> i64 {
            self.id
        }

        fn name(&self) -> &str {
            "Farm"
        }

        fn latitude(&self) -> f64 {
            35.0
        }

        fn longitude(&self) -> f64 {
            135.0
        }

        fn region(&self) -> &str {
            "jp"
        }
    }

    struct TestCrop {
        id: i64,
    }

    impl EntryScheduleCropLike for TestCrop {
        fn id(&self) -> i64 {
            self.id
        }

        fn name(&self) -> &str {
            "Crop"
        }
    }

    impl EntryScheduleShowCrop for TestCrop {}

    struct EmptyTranslator;

    impl TranslatorPort for EmptyTranslator {
        fn translate(&self, _key: &str, _options: &TranslateOptions) -> String {
            String::new()
        }

        fn localize(
            &self,
            _date: Date,
            _format: Option<&str>,
            _options: &TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct FixedClock {
        today: Date,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> time::OffsetDateTime {
            time::OffsetDateTime::new_utc(
                self.today,
                time::Time::from_hms(0, 0, 0).expect("valid"),
            )
        }
    }

    struct SpyOutput {
        success: Option<EntryScheduleShowOutput>,
    }

    impl EntryScheduleShowOutputPort for SpyOutput {
        fn on_success(&mut self, dto: EntryScheduleShowOutput) {
            self.success = Some(dto);
        }

        fn on_failure(&mut self, _failure: EntryScheduleFailure) {}
    }

    struct MockCropGateway;

    impl EntryScheduleCropGateway for MockCropGateway {
        fn list_by_crop_id(&self, _crop_id: i64) -> Vec<CropStageRow> {
            vec![]
        }
    }

    struct RecordingLoader {
        calls: std::sync::Mutex<Vec<(i64, Date, Option<String>)>>,
        payload: BTreeMap<String, Value>,
    }

    impl EntryScheduleWeatherLoaderPort for RecordingLoader {
        fn load_prediction_payload(
            &self,
            farm: &dyn EntryScheduleShowFarm,
            prediction_end_date_raw: Option<&str>,
            reference_date: Date,
        ) -> Result<BTreeMap<String, Value>, Box<dyn std::error::Error + Send + Sync>> {
            self.calls.lock().expect("lock").push((
                farm.id(),
                reference_date,
                prediction_end_date_raw.map(str::to_string),
            ));
            Ok(self.payload.clone())
        }
    }

    struct RecordingRunner {
        calls: std::sync::Mutex<Vec<i64>>,
        result: EntryScheduleWindowResult,
    }

    impl EntryScheduleOptimizationRunnerPort for RecordingRunner {
        fn call(
            &self,
            crop: &dyn EntryScheduleShowCrop,
            _weather_payload: &BTreeMap<String, Value>,
            farm: &dyn EntryScheduleShowFarm,
        ) -> EntryScheduleWindowResult {
            self.calls.lock().expect("lock").push(crop.id());
            let _ = farm.id();
            self.result.clone()
        }
    }

    // Ruby: test "on_success yields dto tied to injected runners"
    #[test]
    fn on_success_yields_dto_tied_to_injected_runners() {
        let farm = TestFarm {
            id: 1,
            weather_location_id: 1,
        };
        let crop = TestCrop { id: 1 };
        let ref_date = Date::from_calendar_date(2026, Month::May, 1).unwrap();

        let mut payload = BTreeMap::new();
        payload.insert("data".into(), json!([{ "time": "2026-01-01" }]));
        payload.insert("generated_at".into(), json!("2026-01-01T00:00:00Z"));
        payload.insert("prediction_end_date".into(), json!("2026-12-31"));

        let loader = RecordingLoader {
            calls: std::sync::Mutex::new(vec![]),
            payload,
        };
        let mut reason_parts = BTreeMap::new();
        reason_parts.insert("error".into(), json!("x"));
        let runner = RecordingRunner {
            calls: std::sync::Mutex::new(vec![]),
            result: EntryScheduleWindowResult {
                eligible: false,
                sowing_windows: vec![],
                transplant_windows: vec![],
                reason_parts,
                sowing_stage_id: None,
                transplant_stage_id: None,
                weather_end_date: Some(Date::from_calendar_date(2026, Month::January, 5).unwrap()),
            },
        };

        let mut output = SpyOutput { success: None };
        let translator = EmptyTranslator;
        let clock = FixedClock { today: ref_date };
        let mut interactor = EntryScheduleShowInteractor::new(
            &mut output,
            &MockCropGateway,
            &loader,
            &runner,
            &translator,
            &clock,
        );

        interactor.call(&farm, &crop, ref_date, Some("2026-10-01"));

        let loader_calls = loader.calls.lock().expect("lock");
        assert_eq!(loader_calls.len(), 1);
        assert_eq!(loader_calls[0].0, 1);
        assert_eq!(loader_calls[0].1, ref_date);
        assert_eq!(loader_calls[0].2.as_deref(), Some("2026-10-01"));

        assert_eq!(*runner.calls.lock().expect("lock"), vec![1]);

        let received = output.success.expect("on_success");
        assert_eq!(
            received.farm_fragment.get("id"),
            Some(&json!(1))
        );
        assert_eq!(
            received.prediction_fragment.get("chart_calendar_year"),
            Some(&json!(2026))
        );
        assert_eq!(
            received.crop_fragment.get("id"),
            Some(&json!(1))
        );
    }
}
