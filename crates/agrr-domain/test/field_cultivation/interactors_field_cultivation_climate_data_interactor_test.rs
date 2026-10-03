// Tests for `interactors/field_cultivation_climate_data_interactor.rs`.

    use std::sync::Arc;

    use serde_json::{json, Value};
    use time::macros::{date, datetime};
    use time::{Date, OffsetDateTime};

    use crate::field_cultivation::dtos::{
        ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement, ClimateThermalRequirement,
        FieldCultivationClimateDataInput, FieldCultivationClimateDataOutput,
        FieldCultivationClimateSourceSnapshot, FieldCultivationPlanAccessSnapshot,
        WeatherPredictionTargets,
    };
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
    }
    impl FieldCultivationClimateDataOutputPort for SpyClimateOutput {
        fn present(&mut self, data: FieldCultivationClimateDataOutput) {
            self.success = Some(data);
        }
        fn on_error(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    struct StubClimateSourceGateway {
        access: FieldCultivationPlanAccessSnapshot,
        source: FieldCultivationClimateSourceSnapshot,
        missing_source_snapshot: bool,
    }
    impl FieldCultivationClimateSourceGateway for StubClimateSourceGateway {
        fn find_plan_access_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>> {
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

    fn run_interactor(
        source: FieldCultivationClimateSourceSnapshot,
        plan_type_public: bool,
        progress: Arc<dyn FieldCultivationClimateProgressGateway>,
        weather_payload: Option<Value>,
        input: FieldCultivationClimateDataInput,
        missing_source_snapshot: bool,
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
        interactor.call(input).expect("interactor call");
        output
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
        assert_eq!(dto.debug_info["using_agrr_progress"], true);
        assert_eq!(dto.gdd_data.len(), 1);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
    }

    #[test]
    fn presents_manual_gdd_when_progress_gateway_returns_empty_records() {
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
        let dto = output
            .success
            .expect("empty agrr progress still yields success-shaped climate data");
        assert_eq!(dto.debug_info["using_agrr_progress"], false);
        assert_eq!(dto.gdd_data.len(), 2);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
    }

    #[test]
    fn presents_manual_gdd_when_progress_gateway_fails() {
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
            Arc::new(FailingProgressGateway),
            Some(sample_weather_payload()),
            FieldCultivationClimateDataInput {
                field_cultivation_id: 1,
                display_start_date: None,
                display_end_date: None,
            },
            false,
        );
        let dto = output.success.expect("climate data still presented on progress failure");
        assert_eq!(dto.debug_info["using_agrr_progress"], false);
        assert_eq!(dto.gdd_data.len(), 2);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
        assert_eq!(dto.gdd_data[0]["cumulative_gdd"], 5.0);
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
        };
        let crop_gateway = StubCropGateway {
            crop: sample_crop(),
        };
        let store = StubWeatherStore { payload: None };
        let mut output = SpyClimateOutput {
            success: None,
            failure: None,
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
