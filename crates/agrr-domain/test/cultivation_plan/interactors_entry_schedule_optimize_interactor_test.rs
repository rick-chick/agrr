// Tests for `interactors/entry_schedule_optimize_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::interactors::entry_schedule::crop_stage_snapshot::CropStageSnapshot;
    use crate::cultivation_plan::interactors::entry_schedule::temperature_requirement_snapshot::TemperatureRequirementSnapshot;
    
    use serde_json::json;
    use std::sync::{Arc, Mutex};
    use time::macros::date;

    struct TestCrop {
        id: i64,
        name: String,
        variety: Option<String>,
    }

    impl CropAgrrRequirementSource for TestCrop {}
    impl EntryScheduleOptimizeCrop for TestCrop {
        fn crop_id(&self) -> i64 {
            self.id
        }
        fn crop_name(&self) -> &str {
            &self.name
        }
        fn crop_variety(&self) -> Option<&str> {
            self.variety.as_deref()
        }
    }

    struct FakeClock {
        today_val: time::Date,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            self.today_val
        }
        fn now(&self) -> time::OffsetDateTime {
            time::OffsetDateTime::UNIX_EPOCH
        }
    }

    struct StubBuilder;
    impl CropAgrrRequirementBuilderPort for StubBuilder {
        fn build_from(&self, _: &dyn CropAgrrRequirementSource) -> Value {
            json!({
                "stage_requirements": [
                    { "thermal": { "required_gdd": 800.0 } },
                    { "thermal": { "required_gdd": 800.0 } }
                ]
            })
        }
    }

    struct StubCropGateway {
        rows: Vec<CropStageSnapshot>,
    }

    impl EntryScheduleCropGateway for StubCropGateway {
        fn entry_schedule_ordered_stage_rows(
            &self,
            _: i64,
        ) -> Result<Vec<CropStageSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.rows.clone())
        }
    }

    enum StubOptimizeOutcome {
        Ok(Value),
        Err(EntryScheduleOptimizationError),
    }

    struct StubOptimizationGateway {
        outcome: StubOptimizeOutcome,
        captured_requirement: Arc<Mutex<Option<Value>>>,
    }

    impl EntryScheduleOptimizationGateway for StubOptimizationGateway {
        fn optimize_period(
            &self,
            _: &str,
            _: Option<&str>,
            _: &Value,
            _: time::Date,
            _: time::Date,
            crop_requirement: &Value,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            *self.captured_requirement.lock().unwrap() = Some(crop_requirement.clone());
            match &self.outcome {
                StubOptimizeOutcome::Ok(v) => Ok(v.clone()),
                StubOptimizeOutcome::Err(e) => Err(Box::new(e.clone())),
            }
        }
    }

    fn weather_rows() -> Value {
        json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "data": [
                { "time": "2026-05-01", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 },
                { "time": "2026-05-02", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 },
                { "time": "2026-05-03", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 }
            ]
        })
    }

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    // Ruby: test "returns disabled result when agrr is not enabled"
    #[test]
    fn returns_disabled_result_when_agrr_is_not_enabled() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: Some("general".into()),
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            false,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key"),
            Some(&json!("disabled"))
        );
    }

    // Ruby: test "evaluation_range intersects last-june through next-june with weather dates"
    #[test]
    fn evaluation_range_intersects_weather_dates() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let range = interactor.evaluation_range().unwrap();
        assert_eq!(range.0, date!(2026-05-01));
        assert_eq!(range.1, date!(2026-05-03));
    }

    // Ruby: test "evaluation_range returns None when weather dates do not overlap ideal window"
    #[test]
    fn evaluation_range_returns_none_when_weather_dates_do_not_overlap_ideal_window() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            json!({
                "latitude": 35.0,
                "longitude": 139.0,
                "data": [
                    { "time": "2024-01-01", "temperature_2m_mean": 15.0 },
                    { "time": "2024-12-31", "temperature_2m_mean": 15.0 }
                ]
            }),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        assert!(interactor.evaluation_range().is_none());
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("insufficient_weather")
        );
        assert!(optimization_gateway.captured_requirement.lock().unwrap().is_none());
    }

    // Ruby: test "scales crop requirement via EntryScheduleStageGddScaler before optimize_period"
    #[test]
    fn scales_crop_requirement_before_optimize_period() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let captured = Arc::new(Mutex::new(None));
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({
                "start_date": "2026-05-01",
                "completion_date": "2026-05-10",
                "days": 10,
                "gdd": 100.0,
                "cost": 1.0
            })),
            captured_requirement: Arc::clone(&captured),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(result.eligible);
        assert_eq!(
            result.reason_parts.get("source").and_then(|v| v.as_str()),
            Some("agrr_optimize_period")
        );
        let req = captured.lock().unwrap().clone().unwrap();
        let total: f64 = req["stage_requirements"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|s| s["thermal"]["required_gdd"].as_f64())
            .sum();
        assert!(total <= 2000.01);
    }

    fn sowing_transplant_stages() -> Vec<CropStageSnapshot> {
        let tr = TemperatureRequirementSnapshot {
            frost_threshold: Some(0.0),
            optimal_min: Some(10.0),
            optimal_max: Some(30.0),
            base_temperature: None,
        };
        vec![
            CropStageSnapshot {
                id: 1,
                name: "播種".into(),
                order: 1,
                temperature_requirement: Some(tr.clone()),
            },
            CropStageSnapshot {
                id: 2,
                name: "定植".into(),
                order: 2,
                temperature_requirement: Some(tr),
            },
        ]
    }

    // Ruby: test "does not fall back to temperature windows when optimize fails"
    #[test]
    fn does_not_fall_back_to_temperature_windows_when_optimize_fails() {
        let crop = TestCrop {
            id: 1,
            name: "かぼちゃ".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway {
            rows: sowing_transplant_stages(),
        };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Err(EntryScheduleOptimizationError::new(
                "execution_failed",
                "FILE_ERROR: Missing required field(s): field_id",
            )),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("source").and_then(|v| v.as_str()),
            Some("agrr_failed")
        );
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("execution_failed")
        );
        assert!(result.sowing_windows.is_empty());
        assert!(result.transplant_windows.is_empty());
    }

    // Ruby: test "maps agrr optimize period response with optimal_start_date to eligible result"
    #[test]
    fn maps_agrr_optimize_period_response_with_optimal_start_date() {
        let crop = TestCrop {
            id: 1,
            name: "Almonds".into(),
            variety: Some("Nonpareil".into()),
        };
        let crop_gateway = StubCropGateway {
            rows: sowing_transplant_stages(),
        };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({
                "optimal_start_date": "2026-03-04",
                "completion_date": "2026-07-06",
                "growth_days": 125,
                "total_cost": 12.5,
                "crop_name": "Almonds",
                "variety": "Nonpareil",
                "candidates": 224
            })),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(result.eligible);
        assert_eq!(
            result.reason_parts.get("optimal_start_date").and_then(|v| v.as_str()),
            Some("2026-03-04")
        );
        assert_eq!(
            result.reason_parts.get("completion_date").and_then(|v| v.as_str()),
            Some("2026-07-06")
        );
        assert_eq!(
            result.reason_parts.get("growth_days").and_then(|v| v.as_i64()),
            Some(125)
        );
        assert_eq!(
            result.reason_parts.get("total_cost").and_then(|v| v.as_f64()),
            Some(12.5)
        );
        assert_eq!(result.sowing_windows[0].start_date, date!(2026-03-04));
        assert_eq!(result.sowing_windows[0].end_date, date!(2026-07-06));
        assert_eq!(result.transplant_windows[0].start_date, date!(2026-03-04));
        assert_eq!(result.transplant_windows[0].end_date, date!(2026-07-06));
    }

    // Ruby: test "returns insufficient_weather when payload has no data rows"
    #[test]
    fn returns_insufficient_weather_when_payload_has_no_data_rows() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            json!({ "latitude": 35.0, "longitude": 139.0, "data": [] }),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("insufficient_weather")
        );
        assert!(optimization_gateway.captured_requirement.lock().unwrap().is_none());
    }

    // Ruby: test "returns insufficient_weather when latitude or longitude is missing"
    #[test]
    fn returns_insufficient_weather_when_coordinates_are_missing() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            json!({
                "data": [
                    { "time": "2026-05-01", "temperature_2m_mean": 15.0 }
                ]
            }),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("insufficient_weather")
        );
    }

    // Ruby: test "returns invalid_response when optimize response omits required dates"
    #[test]
    fn returns_invalid_response_when_optimize_dates_are_missing() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({ "growth_days": 10 })),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("invalid_response")
        );
        assert!(result.sowing_windows.is_empty());
    }

    // Ruby: test "returns invalid_response when completion_date is before start_date"
    #[test]
    fn returns_invalid_response_when_completion_before_start() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({
                "optimal_start_date": "2026-07-10",
                "completion_date": "2026-05-01"
            })),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("invalid_response")
        );
    }

    // Ruby: test "maps non-domain optimize errors to crop_requirement_error"
    #[test]
    fn maps_non_domain_optimize_errors_to_crop_requirement_error() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        #[derive(Debug)]
        struct GenericErr;
        impl std::fmt::Display for GenericErr {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "unexpected")
            }
        }
        impl std::error::Error for GenericErr {}
        struct GenericOptimizationGateway;
        impl EntryScheduleOptimizationGateway for GenericOptimizationGateway {
            fn optimize_period(
                &self,
                _: &str,
                _: Option<&str>,
                _: &Value,
                _: time::Date,
                _: time::Date,
                _: &Value,
                _: &Value,
            ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
                Err(Box::new(GenericErr))
            }
        }
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &GenericOptimizationGateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("crop_requirement_error")
        );
    }

    // Ruby: test "maps EntryScheduleOptimizationError to failed result"
    #[test]
    fn maps_entry_schedule_optimization_error_to_failed_result() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Err(EntryScheduleOptimizationError::new(
                "daemon_unavailable",
                "down",
            )),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("daemon_unavailable")
        );
    }
