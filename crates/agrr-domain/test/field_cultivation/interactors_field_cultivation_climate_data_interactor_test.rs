// Tests for `interactors/field_cultivation_climate_data_interactor.rs`.

    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    use serde_json::{json, Value};
    use time::macros::{date, datetime};
    use time::{Date, OffsetDateTime};

    use crate::field_cultivation::dtos::{
        ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement, ClimateThermalRequirement,
        FieldCultivationClimateDataInput, FieldCultivationClimateDataOutput,
        FieldCultivationClimateFailureReason, FieldCultivationClimateSourceSnapshot,
        FieldCultivationPlanAccessSnapshot, WeatherPredictionTargets,
    };
    use crate::field_cultivation::errors::ClimateProgressGatewayError;
    use crate::field_cultivation::gateways::{
        FieldCultivationClimateProgressGateway, FieldCultivationClimateSourceGateway,
        FieldCultivationCropGateway, FieldCultivationPlanPredictedWeatherGateway,
        FieldCultivationPredictionGateway, FieldCultivationWeatherDataGateway,
        FieldCultivationWeatherPredictionServiceGateway,
    };
    use crate::field_cultivation::ports::{
        FieldCultivationClimateDataInputPort, FieldCultivationClimateDataOutputPort,
        WeatherPredictionAnchors, WeatherPredictionAnchorsPort,
    };
    use crate::shared::dtos::Error;
    use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort, TranslateOptions};
    use crate::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};
    use crate::weather_data::gateways::PredictedWeatherStoreGateway;
    use crate::weather_data::gateways::WeatherDataStorageError;
    use crate::field_cultivation::dtos::ClimateObservedWeatherDatum;
    use crate::field_cultivation::errors::WeatherPayloadInvalidError;
    use crate::shared::exceptions::RecordNotFoundError;

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct RecordingLogger {
        warnings: std::sync::Mutex<Vec<String>>,
    }
    impl LoggerPort for RecordingLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, message: &str) {
            self.warnings.lock().unwrap().push(message.to_string());
        }
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct UncallableProgressGateway;
    impl FieldCultivationClimateProgressGateway for UncallableProgressGateway {
        fn calculate_progress(
            &self,
            _: &Value,
            _: Date,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            panic!("progress gateway must not be called when crop requirement is incomplete");
        }
    }

    struct FixedClock(Date);
    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.0
        }
        fn now(&self) -> OffsetDateTime {
            datetime!(2026-10-01 12:00 UTC)
        }
    }

    struct SpyClimateOutput {
        success: Option<FieldCultivationClimateDataOutput>,
        failure: Option<Error>,
        climate_failure: Option<crate::field_cultivation::dtos::FieldCultivationClimateFailure>,
    }
    impl FieldCultivationClimateDataOutputPort for SpyClimateOutput {
        fn present(&mut self, data: FieldCultivationClimateDataOutput) {
            self.success = Some(data);
        }
        fn on_error(&mut self, error: Error) {
            self.failure = Some(error);
        }
        fn on_failure(
            &mut self,
            failure: crate::field_cultivation::dtos::FieldCultivationClimateFailure,
        ) {
            self.climate_failure = Some(failure);
        }
    }

    struct StubClimateSourceGateway {
        access: FieldCultivationPlanAccessSnapshot,
        source: FieldCultivationClimateSourceSnapshot,
        missing_source_snapshot: bool,
        missing_plan_access_snapshot: bool,
    }
    impl FieldCultivationClimateSourceGateway for StubClimateSourceGateway {
        fn find_plan_access_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            if self.missing_plan_access_snapshot {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.access.clone())
        }
        fn find_climate_source_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationClimateSourceSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            if self.missing_source_snapshot {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.source.clone())
        }
        fn find_weather_prediction_targets_by_plan_id(
            &self,
            _: i64,
        ) -> Result<WeatherPredictionTargets, Box<dyn std::error::Error + Send + Sync>> {
            Ok(WeatherPredictionTargets {
                weather_location: json!({}),
                farm: json!({}),
            })
        }
    }

    struct StubCropGateway {
        crop: ClimateCropEntity,
    }
    impl FieldCultivationCropGateway for StubCropGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<ClimateCropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.crop.clone())
        }
    }

    struct ErrWeatherStore;
    impl PredictedWeatherStoreGateway for ErrWeatherStore {
        fn read_payload(
            &self,
            _: PredictedWeatherScope,
            _: i64,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            Err("predicted_weather_store_unavailable".into())
        }
        fn write_payload(
            &self,
            _: PredictedWeatherScope,
            _: i64,
            _: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unreachable!()
        }
        fn copy_plan_payload(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unreachable!()
        }
    }

    struct StubWeatherStore {
        payload: Option<Value>,
    }
    impl PredictedWeatherStoreGateway for StubWeatherStore {
        fn read_payload(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            if scope == PredictedWeatherScope::Plan && scope_id == 5 {
                Ok(self.payload.clone())
            } else {
                Ok(None)
            }
        }
        fn write_payload(
            &self,
            _: PredictedWeatherScope,
            _: i64,
            _: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
        fn copy_plan_payload(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FailingProgressGateway;
    impl FieldCultivationClimateProgressGateway for FailingProgressGateway {
        fn calculate_progress(
            &self,
            _: &Value,
            _: Date,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Err("daemon_unavailable".into())
        }
    }

    struct DaemonUnavailableProgressGateway;
    impl FieldCultivationClimateProgressGateway for DaemonUnavailableProgressGateway {
        fn calculate_progress(
            &self,
            _: &Value,
            _: Date,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(ClimateProgressGatewayError::DaemonUnavailable))
        }
    }

    struct ExecutionFailedProgressGateway;
    impl FieldCultivationClimateProgressGateway for ExecutionFailedProgressGateway {
        fn calculate_progress(
            &self,
            _: &Value,
            _: Date,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(ClimateProgressGatewayError::ExecutionFailed(
                "agrr exit 1".into(),
            )))
        }
    }

    struct OkProgressGateway {
        result: Value,
    }
    impl FieldCultivationClimateProgressGateway for OkProgressGateway {
        fn calculate_progress(
            &self,
            _: &Value,
            _: Date,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.result.clone())
        }
    }

    struct UnreachableWeatherDataGateway;
    impl FieldCultivationWeatherDataGateway for UnreachableWeatherDataGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<ClimateObservedWeatherDatum>, WeatherDataStorageError> {
            unreachable!("observed merge should be skipped for future cultivation period")
        }
        fn format_for_agrr(&self, _: &[ClimateObservedWeatherDatum], _: &Value) -> Value {
            unreachable!()
        }
    }

    struct UnreachableWeatherPredictionGateway;
    impl FieldCultivationWeatherPredictionServiceGateway for UnreachableWeatherPredictionGateway {
        fn predict_for_cultivation_plan(
            &self,
            _: &Value,
            _: &Value,
            _: &crate::field_cultivation::dtos::CultivationPlanWeatherInput,
        ) -> Option<Value> {
            unreachable!("cached prediction path should not invoke on-the-fly prediction")
        }
    }

    struct UnreachablePredictionGateway;
    impl FieldCultivationPredictionGateway for UnreachablePredictionGateway {
        fn predict(&self, _: &Value, _: i64, _: &str) -> Option<Value> {
            unreachable!()
        }
    }

    struct NullPredictionGateway;
    impl FieldCultivationPredictionGateway for NullPredictionGateway {
        fn predict(&self, _: &Value, _: i64, _: &str) -> Option<Value> {
            None
        }
    }

    struct UnreachablePlanPredictedWeatherGateway;
    impl FieldCultivationPlanPredictedWeatherGateway for UnreachablePlanPredictedWeatherGateway {
        fn find_plan_metadata(
            &self,
            _: i64,
        ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn persist_plan_prediction(
            &self,
            _: i64,
            _: &Value,
            _: Date,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unreachable!()
        }
    }

    struct FixedAnchors;
    impl WeatherPredictionAnchorsPort for FixedAnchors {
        fn anchors_for(&self, _: Date) -> WeatherPredictionAnchors {
            WeatherPredictionAnchors {
                training_start_date: date!(2020 - 01 - 01),
                training_end_date: date!(2025 - 12 - 31),
            }
        }
    }

    struct CountingWeatherPredictionGateway {
        calls: AtomicUsize,
    }
    impl FieldCultivationWeatherPredictionServiceGateway for CountingWeatherPredictionGateway {
        fn predict_for_cultivation_plan(
            &self,
            _: &Value,
            _: &Value,
            _: &crate::field_cultivation::dtos::CultivationPlanWeatherInput,
        ) -> Option<Value> {
            self.calls.fetch_add(1, Ordering::SeqCst);
            None
        }
    }

    struct ObservedOnlyFallbackWeatherDataGateway;
    impl FieldCultivationWeatherDataGateway for ObservedOnlyFallbackWeatherDataGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<ClimateObservedWeatherDatum>, WeatherDataStorageError> {
            Ok(vec![ClimateObservedWeatherDatum {
                date: date!(2025 - 06 - 01),
                temperature_max: Some(20.0),
                temperature_min: Some(10.0),
                temperature_mean: Some(15.0),
                precipitation: None,
                sunshine_hours: None,
                wind_speed: None,
                weather_code: None,
            }])
        }

        fn format_for_agrr(&self, records: &[ClimateObservedWeatherDatum], _: &Value) -> Value {
            let data: Vec<Value> = records
                .iter()
                .map(|row| {
                    json!({
                        "time": row.date.to_string(),
                        "temperature_2m_max": row.temperature_max,
                        "temperature_2m_min": row.temperature_min,
                    })
                })
                .collect();
            json!({ "data": data })
        }
    }

    struct RecordingPlanPredictedWeatherGateway {
        persist_calls: AtomicUsize,
    }
    impl FieldCultivationPlanPredictedWeatherGateway for RecordingPlanPredictedWeatherGateway {
        fn find_plan_metadata(
            &self,
            _: i64,
        ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }

        fn persist_plan_prediction(
            &self,
            _: i64,
            _: &Value,
            _: Date,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.persist_calls.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }
    }

    fn sample_crop() -> ClimateCropEntity {
        ClimateCropEntity {
            id: 2,
            name: "Tomato".into(),
            variety: None,
            area_per_unit: Some(0.25),
            revenue_per_area: Some(5000.0),
            groups: json!([]),
            is_reference: true,
            user_id: None,
            crop_stages: vec![ClimateCropStage {
                name: "Stage1".into(),
                order: 1,
                temperature_requirement: Some(ClimateTemperatureRequirement {
                    base_temperature: 10.0,
                    optimal_min: Some(15.0),
                    optimal_max: Some(25.0),
                    low_stress_threshold: None,
                    high_stress_threshold: None,
                    frost_threshold: None,
                    max_temperature: Some(50.0),
                }),
                thermal_requirement: Some(ClimateThermalRequirement {
                    required_gdd: 100.0,
                }),
            }],
        }
    }

    fn sample_plan_metadata() -> PredictedWeatherMetadata {
        PredictedWeatherMetadata {
            scope: PredictedWeatherScope::Plan,
            scope_id: 5,
            prediction_start_date: date!(2027 - 01 - 01),
            prediction_end_date: date!(2027 - 12 - 31),
            target_end_date: date!(2027 - 12 - 31),
            data_end_date: date!(2027 - 12 - 31),
            generated_at: "test".into(),
        }
    }

    fn sample_source(
        weather_location_id: Option<i64>,
        start_date: Option<Date>,
        completion_date: Option<Date>,
        plan_type_public: bool,
        plan_crop_crop_id: Option<i64>,
    ) -> FieldCultivationClimateSourceSnapshot {
        FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: 1,
            field_name: "Field A".into(),
            crop_name: "Tomato".into(),
            start_date,
            completion_date,
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            weather_location_id,
            weather_location_timezone: Some("Asia/Tokyo".into()),
            plan_id: 5,
            plan_type_public,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: Some(sample_plan_metadata()),
            plan_crop_crop_id,
        }
    }

    fn sample_source_without_plan_metadata(
        weather_location_id: Option<i64>,
        start_date: Option<Date>,
        completion_date: Option<Date>,
        plan_type_public: bool,
        plan_crop_crop_id: Option<i64>,
    ) -> FieldCultivationClimateSourceSnapshot {
        let mut source = sample_source(
            weather_location_id,
            start_date,
            completion_date,
            plan_type_public,
            plan_crop_crop_id,
        );
        source.plan_metadata = None;
        source
    }

    fn sample_weather_payload() -> Value {
        json!({
            "data": [
                {
                    "time": "2027-01-01",
                    "temperature_2m_max": 20.0,
                    "temperature_2m_min": 10.0
                },
                {
                    "time": "2027-01-02",
                    "temperature_2m_max": 18.0,
                    "temperature_2m_min": 8.0
                }
            ]
        })
    }

    fn run_interactor_with_crop_and_logger(
        source: FieldCultivationClimateSourceSnapshot,
        plan_type_public: bool,
        progress: Arc<dyn FieldCultivationClimateProgressGateway>,
        weather_payload: Option<Value>,
        input: FieldCultivationClimateDataInput,
        missing_source_snapshot: bool,
        crop: ClimateCropEntity,
        logger: &dyn LoggerPort,
    ) -> SpyClimateOutput {
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            plan_type_public,
            !plan_type_public,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway { crop };
        let store = StubWeatherStore {
            payload: weather_payload,
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        interactor.call(input).expect("interactor call");
        output
    }

    fn run_interactor_with_crop(
        source: FieldCultivationClimateSourceSnapshot,
        plan_type_public: bool,
        progress: Arc<dyn FieldCultivationClimateProgressGateway>,
        weather_payload: Option<Value>,
        input: FieldCultivationClimateDataInput,
        missing_source_snapshot: bool,
        crop: ClimateCropEntity,
    ) -> SpyClimateOutput {
        run_interactor_with_crop_and_logger(
            source,
            plan_type_public,
            progress,
            weather_payload,
            input,
            missing_source_snapshot,
            crop,
            &NoopLogger,
        )
    }

    fn run_interactor(
        source: FieldCultivationClimateSourceSnapshot,
        plan_type_public: bool,
        progress: Arc<dyn FieldCultivationClimateProgressGateway>,
        weather_payload: Option<Value>,
        input: FieldCultivationClimateDataInput,
        missing_source_snapshot: bool,
    ) -> SpyClimateOutput {
        run_interactor_with_crop(
            source,
            plan_type_public,
            progress,
            weather_payload,
            input,
            missing_source_snapshot,
            sample_crop(),
        )
    }

    fn run_interactor_result(
        source: FieldCultivationClimateSourceSnapshot,
        plan_type_public: bool,
        progress: Arc<dyn FieldCultivationClimateProgressGateway>,
        weather_payload: Option<Value>,
        input: FieldCultivationClimateDataInput,
        missing_source_snapshot: bool,
    ) -> (SpyClimateOutput, Result<(), Box<dyn std::error::Error + Send + Sync>>) {
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            plan_type_public,
            !plan_type_public,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = StubWeatherStore {
            payload: weather_payload,
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let logger = NoopLogger;
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        let call_result = interactor.call(input);
        (output, call_result)
    }

    #[test]
    fn on_error_when_weather_location_is_missing() {
        let source = sample_source(
            None,
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 10)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        assert_eq!(
            output.failure.unwrap().message,
            "api.errors.no_weather_data"
        );
    }

    #[test]
    fn on_error_when_cultivation_period_is_missing() {
        let source = sample_source(
            Some(1),
            None,
            Some(date!(2027 - 01 - 10)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        assert_eq!(
            output.failure.unwrap().message,
            "api.errors.no_cultivation_period"
        );
    }

    #[test]
    fn forbidden_for_anonymous_access_to_private_plan() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 10)),
            false,
            Some(2),
        );
        let output = run_interactor(
            source,
            false,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        assert_eq!(output.failure.unwrap().message, "Forbidden");
    }

    fn crop_without_valid_stages() -> ClimateCropEntity {
        ClimateCropEntity {
            id: 2,
            name: "Incomplete".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: json!([]),
            is_reference: true,
            user_id: None,
            crop_stages: vec![ClimateCropStage {
                name: "Stage1".into(),
                order: 1,
                temperature_requirement: None,
                thermal_requirement: None,
            }],
        }
    }

    fn crop_with_missing_temperature_on_lowest_order_stage() -> ClimateCropEntity {
        ClimateCropEntity {
            id: 2,
            name: "Incomplete".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: json!([]),
            is_reference: true,
            user_id: None,
            crop_stages: vec![
                ClimateCropStage {
                    name: "Early".into(),
                    order: 1,
                    temperature_requirement: None,
                    thermal_requirement: Some(ClimateThermalRequirement {
                        required_gdd: 100.0,
                    }),
                },
                ClimateCropStage {
                    name: "Late".into(),
                    order: 2,
                    temperature_requirement: Some(ClimateTemperatureRequirement {
                        base_temperature: 10.0,
                        optimal_min: Some(15.0),
                        optimal_max: Some(25.0),
                        low_stress_threshold: None,
                        high_stress_threshold: None,
                        frost_threshold: None,
                        max_temperature: Some(50.0),
                    }),
                    thermal_requirement: Some(ClimateThermalRequirement {
                        required_gdd: 200.0,
                    }),
                },
            ],
        }
    }

    #[test]
    fn on_failure_when_crop_has_no_valid_stages_without_calling_progress() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor_with_crop(
            source,
            true,
            Arc::new(UncallableProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
            crop_without_valid_stages(),
        );
        assert!(output.success.is_none());
        let failure = output.climate_failure.expect("typed climate failure");
        assert_eq!(
            failure.reason,
            FieldCultivationClimateFailureReason::CropRequirementIncomplete
        );
    }

    #[test]
    fn on_failure_when_lowest_order_stage_lacks_temperature_requirement() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor_with_crop(
            source,
            true,
            Arc::new(UncallableProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
            crop_with_missing_temperature_on_lowest_order_stage(),
        );
        assert!(output.success.is_none());
        let failure = output.climate_failure.expect("typed climate failure");
        assert_eq!(
            failure.reason,
            FieldCultivationClimateFailureReason::CropRequirementIncomplete
        );
    }

    #[test]
    fn logs_crop_requirement_incomplete_before_on_failure() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let logger = RecordingLogger {
            warnings: std::sync::Mutex::new(Vec::new()),
        };
        let output = run_interactor_with_crop_and_logger(
            source,
            true,
            Arc::new(UncallableProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
            crop_without_valid_stages(),
            &logger,
        );
        assert!(output.success.is_none());
        assert_eq!(
            output
                .climate_failure
                .expect("failure")
                .reason,
            FieldCultivationClimateFailureReason::CropRequirementIncomplete
        );
        let warnings = logger.warnings.lock().unwrap();
        assert_eq!(warnings.len(), 1);
        assert!(warnings[0].contains("Crop requirement incomplete"));
        assert!(warnings[0].contains("no stages with temperature and thermal requirements"));
    }

    #[test]
    fn presents_agrr_progress_when_gateway_succeeds() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let progress = json!({
            "progress_records": [
                { "date": "2027-01-01", "cumulative_gdd": 5.0, "stage_name": "Stage1" }
            ]
        });
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway { result: progress }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        let dto = output.success.expect("climate data presented");
        assert_eq!(dto.gdd_data.len(), 1);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
        assert!(output.climate_failure.is_none());
    }

    #[test]
    fn on_failure_when_progress_gateway_returns_empty_records() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        let failure = output.climate_failure.expect("typed climate failure");
        assert_eq!(
            failure.reason,
            FieldCultivationClimateFailureReason::ProgressResultInvalid
        );
        assert!(failure.message.contains("in_period_weather_rows=2"));
    }

    #[test]
    fn propagates_untyped_error_when_progress_gateway_fails() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let (output, call_result) = run_interactor_result(
            source,
            true,
            Arc::new(FailingProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(call_result.is_err());
        assert!(output.success.is_none());
        assert!(output.climate_failure.is_none());
    }

    #[test]
    fn on_failure_when_progress_gateway_reports_daemon_unavailable() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(DaemonUnavailableProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        let failure = output.climate_failure.expect("daemon failure");
        assert_eq!(
            failure.reason,
            FieldCultivationClimateFailureReason::ProgressDaemonUnavailable
        );
    }

    #[test]
    fn on_failure_when_progress_gateway_reports_execution_failed() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(ExecutionFailedProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        let failure = output.climate_failure.expect("execution failure");
        assert_eq!(
            failure.reason,
            FieldCultivationClimateFailureReason::ProgressExecutionFailed
        );
    }

    #[test]
    fn apply_display_range_intersects_gantt_bounds_with_cultivation_period() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 05)),
            true,
            Some(2),
        );
        let progress = json!({
            "progress_records": [
                { "date": "2027-01-01", "cumulative_gdd": 5.0, "stage_name": "Stage1" },
                { "date": "2027-01-02", "cumulative_gdd": 10.0, "stage_name": "Stage1" },
                { "date": "2027-01-03", "cumulative_gdd": 15.0, "stage_name": "Stage1" }
            ]
        });
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway { result: progress }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: Some("2027-01-02".into()),
                display_end_date: Some("2027-01-02".into()),
            },
            false,
        );
        let dto = output.success.expect("climate data presented");
        assert_eq!(dto.weather_data.len(), 1);
        assert_eq!(dto.weather_data[0]["date"], "2027-01-02");
        assert_eq!(dto.gdd_data.len(), 1);
        assert_eq!(dto.gdd_data[0]["date"], "2027-01-02");
        let display_range = dto.debug_info["display_range"]
            .as_object()
            .expect("display_range metadata");
        assert_eq!(display_range["effective_start"], "2027-01-02");
        assert_eq!(display_range["effective_end"], "2027-01-02");
        assert_eq!(display_range["weather_records"], 1);
        assert_eq!(display_range["gdd_records"], 1);
    }

    #[test]
    fn on_error_when_plan_crop_is_unlinked() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            None,
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        assert!(output.success.is_none());
        assert_eq!(
            output.failure.unwrap().message,
            "api.errors.crop_not_found"
        );
    }

    #[test]
    fn on_error_when_climate_source_snapshot_is_missing() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway {
                result: json!({ "progress_records": [] }),
            }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            true,
        );
        assert!(output.success.is_none());
        assert_eq!(
            output.failure.unwrap().message,
            "record not found"
        );
    }

    #[test]
    fn propagates_error_when_plan_prediction_store_read_fails() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            true,
            false,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = ErrWeatherStore;
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let logger = NoopLogger;
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;
        let progress = Arc::new(OkProgressGateway {
            result: json!({ "progress_records": [] }),
        });

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        let err = interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect_err("store read failure must propagate");
        assert!(err.to_string().contains("predicted_weather_store_unavailable"));
        assert!(output.success.is_none());
        assert!(output.failure.is_none());
    }

    #[test]
    fn returns_weather_payload_invalid_error_when_cached_plan_prediction_is_absent() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            true,
            false,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = StubWeatherStore { payload: None };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let logger = NoopLogger;
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;
        let progress = Arc::new(OkProgressGateway {
            result: json!({ "progress_records": [] }),
        });

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        let err = interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect_err("missing cached prediction should fail closed");
        assert!(err.downcast_ref::<WeatherPayloadInvalidError>().is_some());
        assert!(output.success.is_none());
        assert!(output.failure.is_none());
    }

    #[test]
    fn returns_weather_payload_invalid_error_when_cached_payload_has_no_data() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            true,
            false,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = StubWeatherStore {
            payload: Some(json!({})),
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let logger = NoopLogger;
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;
        let progress = Arc::new(OkProgressGateway {
            result: json!({ "progress_records": [] }),
        });

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        let err = interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect_err("invalid cached weather payload should fail closed");
        assert!(err.downcast_ref::<WeatherPayloadInvalidError>().is_some());
        assert!(output.success.is_none());
        assert!(output.failure.is_none());
    }

    #[test]
    fn on_error_when_field_cultivation_plan_access_snapshot_is_missing() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let access = FieldCultivationPlanAccessSnapshot::new(
            source.field_cultivation_id,
            true,
            false,
            Some(99),
            None,
        );
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: true,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = StubWeatherStore {
            payload: Some(sample_weather_payload()),
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let logger = NoopLogger;
        let clock = FixedClock(date!(2026 - 10 - 01));
        let translator = StubTranslator;
        let weather_data = UnreachableWeatherDataGateway;
        let weather_prediction = UnreachableWeatherPredictionGateway;
        let prediction = UnreachablePredictionGateway;
        let plan_predicted = UnreachablePlanPredictedWeatherGateway;
        let anchors = FixedAnchors;
        let progress = Arc::new(OkProgressGateway {
            result: json!({ "progress_records": [] }),
        });

        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &logger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &anchors,
            progress.as_ref(),
            &clock,
            &translator,
        );
        interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect("record not found is surfaced via output port");
        assert!(output.success.is_none());
        assert_eq!(output.failure.unwrap().message, "record not found");
    }

    #[test]
    fn ignores_invalid_display_range_strings_and_returns_full_series() {
        let source = sample_source(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 02)),
            true,
            Some(2),
        );
        let progress = json!({
            "progress_records": [
                { "date": "2027-01-01", "cumulative_gdd": 5.0, "stage_name": "Stage1" },
                { "date": "2027-01-02", "cumulative_gdd": 10.0, "stage_name": "Stage1" }
            ]
        });
        let output = run_interactor(
            source,
            true,
            Arc::new(OkProgressGateway { result: progress }),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: Some("not-a-date".into()),
                display_end_date: Some("also-invalid".into()),
            },
            false,
        );
        let dto = output.success.expect("climate data presented");
        assert_eq!(dto.weather_data.len(), 2);
        assert_eq!(dto.gdd_data.len(), 2);
        assert!(dto.debug_info.get("display_range").is_none());
    }

    // Locks on-the-fly prediction path (docs/spec-defects/06 item 3) before fallback removal.
    #[test]
    fn invokes_plan_prediction_when_plan_has_no_cached_metadata() {
        let source = sample_source_without_plan_metadata(
            Some(1),
            Some(date!(2027 - 01 - 01)),
            Some(date!(2027 - 01 - 10)),
            true,
            Some(2),
        );
        let weather_prediction = CountingWeatherPredictionGateway {
            calls: AtomicUsize::new(0),
        };
        let access = FieldCultivationPlanAccessSnapshot::new(1, true, false, Some(99), None);
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let weather_data = ObservedOnlyFallbackWeatherDataGateway;
        let prediction = NullPredictionGateway;
        let plan_predicted = RecordingPlanPredictedWeatherGateway {
            persist_calls: AtomicUsize::new(0),
        };
        let store = StubWeatherStore { payload: None };
        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &NoopLogger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &FixedAnchors,
            &FailingProgressGateway,
            &FixedClock(date!(2026 - 10 - 01)),
            &StubTranslator,
        );
        interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect("interactor call");
        assert_eq!(weather_prediction.calls.load(Ordering::SeqCst), 1);
        assert!(output.success.is_none());
        assert_eq!(
            output.failure.unwrap().message,
            "Field cultivation climate data not found"
        );
    }

    #[test]
    fn presents_climate_via_observed_fallback_when_plan_has_no_cached_metadata() {
        let source = sample_source_without_plan_metadata(
            Some(1),
            Some(date!(2025 - 06 - 01)),
            Some(date!(2025 - 06 - 15)),
            true,
            Some(2),
        );
        let weather_prediction = CountingWeatherPredictionGateway {
            calls: AtomicUsize::new(0),
        };
        let access = FieldCultivationPlanAccessSnapshot::new(1, true, false, Some(99), None);
        let climate_source = StubClimateSourceGateway {
            access,
            source,
            missing_source_snapshot: false,
            missing_plan_access_snapshot: false,
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
            climate_failure: None,
        };
        let weather_data = ObservedOnlyFallbackWeatherDataGateway;
        let prediction = NullPredictionGateway;
        let plan_predicted = RecordingPlanPredictedWeatherGateway {
            persist_calls: AtomicUsize::new(0),
        };
        let store = StubWeatherStore { payload: None };
        let progress = Arc::new(OkProgressGateway {
            result: json!({
                "progress_records": [
                    { "date": "2025-06-01", "cumulative_gdd": 5.0, "stage_name": "Stage1" }
                ]
            }),
        });
        let mut interactor = FieldCultivationClimateDataInteractor::new(
            &mut output,
            &NoopLogger,
            None,
            None,
            &climate_source,
            &crop_gateway,
            &weather_data,
            &weather_prediction,
            &prediction,
            &plan_predicted,
            &store,
            &FixedAnchors,
            progress.as_ref(),
            &FixedClock(date!(2026 - 10 - 01)),
            &StubTranslator,
        );
        interactor
            .call(FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            })
            .expect("interactor call");
        assert_eq!(weather_prediction.calls.load(Ordering::SeqCst), 1);
        assert_eq!(plan_predicted.persist_calls.load(Ordering::SeqCst), 1);
        let dto = output.success.expect("climate data presented via fallback");
        assert_eq!(dto.weather_data.len(), 1);
        assert!(!dto.gdd_data.is_empty());
    }
