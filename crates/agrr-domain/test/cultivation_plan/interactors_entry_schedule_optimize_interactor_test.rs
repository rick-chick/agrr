// Tests for `interactors/entry_schedule_optimize_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

use serde_json::json;

    use crate::cultivation_plan::interactors::entry_schedule::temperature_requirement_snapshot::TemperatureRequirementSnapshot;
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
