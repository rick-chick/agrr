// Tests for `interactors/public_plan_create_interactor.rs` (Ruby parity under test/domain/public_plan/).

    use crate::public_plan::dtos::{PublicPlanCrop, PublicPlanFarm};
    use crate::public_plan::ports::PlanInitializerResult;
    use std::sync::{Arc, Mutex};

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

    struct CapturingLogger {
        lines: Mutex<Vec<String>>,
    }

    impl LoggerPort for CapturingLogger {
        fn info(&self, message: &str) {
            self.lines.lock().expect("lock").push(message.to_string());
        }
        fn warn(&self, message: &str) {
            self.lines.lock().expect("lock").push(message.to_string());
        }
        fn error(&self, message: &str) {
            self.lines.lock().expect("lock").push(message.to_string());
        }
        fn debug(&self, message: &str) {
            self.lines.lock().expect("lock").push(message.to_string());
        }
    }

    struct RecordingOutput {
        success: Option<PublicPlanCreateOutput>,
        failure: Option<Error>,
        no_crops: Option<PublicPlanCreateNoCropsViewContext>,
        events: Arc<Mutex<Vec<&'static str>>>,
    }

    impl PublicPlanCreateOutputPort for RecordingOutput {
        fn on_success(&mut self, dto: PublicPlanCreateOutput) {
            self.success = Some(dto);
            self.events.lock().expect("lock").push("success");
        }

        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
            self.events.lock().expect("lock").push("failure");
        }

        fn on_no_crops_failure(&mut self, ctx: PublicPlanCreateNoCropsViewContext) {
            self.no_crops = Some(ctx);
            self.events.lock().expect("lock").push("no_crops_failure");
        }
    }

    struct FakeGateway {
        farm: Option<PublicPlanFarm>,
        farm_size: Option<crate::public_plan::catalog::FarmSizeRecord>,
        crops: Vec<PublicPlanCrop>,
        farm_size_error: bool,
    }

    impl PublicPlanGateway for FakeGateway {
        fn find_by_farm_id(&self, _farm_id: i64) -> Option<PublicPlanFarm> {
            self.farm.clone()
        }

        fn find_by_farm_size_id(&self, _farm_size_id: &str) -> Option<crate::public_plan::catalog::FarmSizeRecord> {
            if self.farm_size_error {
                panic!("Database error");
            }
            self.farm_size.clone()
        }

        fn list_by_ids(&self, _crop_ids: &[i64], _region: &str) -> Vec<PublicPlanCrop> {
            self.crops.clone()
        }
    }

    struct FakeCropGateway {
        crops: Vec<PublicPlanCrop>,
        error: bool,
    }

    impl PublicPlanCropGateway for FakeCropGateway {
        fn list_by_is_reference(
            &self,
            _is_reference: bool,
            _region: Option<&str>,
        ) -> Result<Vec<PublicPlanCrop>, RecordInvalidError> {
            if self.error {
                Err(RecordInvalidError::new(Some("invalid".into()), None))
            } else {
                Ok(self.crops.clone())
            }
        }
    }

    struct FakeInitializer {
        result: PlanInitializerResult,
    }

    impl PlanInitializerPort for FakeInitializer {
        fn call(
            &self,
            _farm: &PublicPlanFarm,
            _total_area: i64,
            _crops: &[PublicPlanCrop],
            _user_id: Option<i64>,
            _session_id: &str,
            _plan_type: &str,
            _planning_start_date: Date,
            _planning_end_date: Date,
        ) -> PlanInitializerResult {
            self.result.clone()
        }
    }

    struct FakeJobChain {
        calls: Mutex<Vec<(i64, String, Option<String>)>>,
        events: Arc<Mutex<Vec<&'static str>>>,
    }

    impl PublicPlanOptimizationJobChainGateway for FakeJobChain {
        fn enqueue_after_create(
            &self,
            cultivation_plan_id: i64,
            caller_label: &str,
            redirect_path: Option<&str>,
        ) {
            self.events.lock().expect("lock").push("enqueue");
            self.calls.lock().expect("lock").push((
                cultivation_plan_id,
                caller_label.to_string(),
                redirect_path.map(str::to_string),
            ));
        }
    }

    fn standard_farm() -> PublicPlanFarm {
        PublicPlanFarm {
            id: 1,
            name: "テスト農場".into(),
            region: "Kyoto".into(),
        }
    }

    fn standard_gateway() -> FakeGateway {
        FakeGateway {
            farm: Some(standard_farm()),
            farm_size: Some(crate::public_plan::catalog::FarmSizeRecord {
                id: "home_garden".into(),
                area_sqm: 30,
            }),
            crops: vec![PublicPlanCrop {
                id: 1,
                name: "トマト".into(),
            }],
            farm_size_error: false,
        }
    }

    fn standard_input() -> PublicPlanCreateInput {
        PublicPlanCreateInput::new(1, "home_garden", vec![1], "session123")
    }

    // Ruby: test "initialize requires a clock responding to :today"
    #[test]
    fn initialize_requires_a_clock_responding_to_today() {
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        assert!(validate_clock(&clock).is_ok());
    }

    // Ruby: test "calls on_success with the created plan_id when initialization succeeds"
    #[test]
    fn calls_on_success_with_the_created_plan_id_when_initialization_succeeds() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::success(123),
        };
        let gateway = standard_gateway();
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert!(output.failure.is_none());
        assert_eq!(output.success.expect("success").plan_id, 123);
    }

    // Ruby: test "enqueues the optimization job chain before calling on_success"
    #[test]
    fn enqueues_the_optimization_job_chain_before_calling_on_success() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::success(123),
        };
        let job_chain = FakeJobChain {
            calls: Mutex::new(vec![]),
            events: Arc::clone(&output.events),
        };
        let gateway = standard_gateway();
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            Some(&job_chain),
        );
        interactor.call(standard_input());

        assert_eq!(
            *output.events.lock().expect("lock"),
            vec!["enqueue", "success"]
        );
        let calls = job_chain.calls.lock().expect("lock");
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, 123);
        assert_eq!(calls[0].1, CALLER_LABEL);
    }

    // Ruby: test "calls on_failure when the farm is not found"
    #[test]
    fn calls_on_failure_when_the_farm_is_not_found() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: None,
            farm_size: None,
            crops: vec![],
            farm_size_error: false,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert!(output.failure.expect("failure").message.contains("Farm not found"));
    }

    // Ruby: test "calls on_failure when the farm size is invalid"
    #[test]
    fn calls_on_failure_when_the_farm_size_is_invalid() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: Some(standard_farm()),
            farm_size: None,
            crops: vec![],
            farm_size_error: false,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(PublicPlanCreateInput::new(1, "invalid_size", vec![1], "session123"));

        assert!(
            output
                .failure
                .expect("failure")
                .message
                .contains("Invalid farm size")
        );
    }

    // Ruby: test "calls on_failure when the total area is not positive"
    #[test]
    fn calls_on_failure_when_the_total_area_is_not_positive() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: Some(standard_farm()),
            farm_size: Some(crate::public_plan::catalog::FarmSizeRecord {
                id: "x".into(),
                area_sqm: 0,
            }),
            crops: vec![],
            farm_size_error: false,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert!(
            output
                .failure
                .expect("failure")
                .message
                .contains("Invalid total area")
        );
    }

    // Ruby: test "calls on_no_crops_failure with view context when no crops are resolved"
    #[test]
    fn calls_on_no_crops_failure_with_view_context_when_no_crops_are_resolved() {
        let reference_crops = vec![PublicPlanCrop {
            id: 10,
            name: "参照作物".into(),
        }];
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: Some(standard_farm()),
            farm_size: Some(crate::public_plan::catalog::FarmSizeRecord {
                id: "home_garden".into(),
                area_sqm: 30,
            }),
            crops: vec![],
            farm_size_error: false,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: reference_crops.clone(),
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert!(output.failure.is_none());
        assert!(output
            .events
            .lock()
            .expect("lock")
            .contains(&"no_crops_failure"));
        let ctx = output.no_crops.expect("no_crops");
        assert_eq!(ctx.farm, standard_farm());
        assert_eq!(ctx.farm_size.id, "home_garden");
        assert_eq!(ctx.crops, reference_crops);
    }

    // Ruby: test "calls on_no_crops_failure with empty crops when reference crop list raises RecordInvalid"
    #[test]
    fn calls_on_no_crops_failure_with_empty_crops_when_reference_crop_list_raises_record_invalid(
    ) {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: Some(standard_farm()),
            farm_size: Some(crate::public_plan::catalog::FarmSizeRecord {
                id: "home_garden".into(),
                area_sqm: 30,
            }),
            crops: vec![],
            farm_size_error: false,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: true,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert_eq!(output.no_crops.expect("no_crops").crops, vec![]);
    }

    // Ruby: test "calls on_failure when the cultivation plan initialization reports errors"
    #[test]
    fn calls_on_failure_when_the_cultivation_plan_initialization_reports_errors() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec!["Creation failed".into()]),
        };
        let gateway = standard_gateway();
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());

        assert!(
            output
                .failure
                .expect("failure")
                .message
                .contains("Creation failed")
        );
    }

    // Ruby: test "propagates unexpected errors raised while reading the farm size"
    #[test]
    #[should_panic(expected = "Database error")]
    fn propagates_unexpected_errors_raised_while_reading_the_farm_size() {
        let mut output = RecordingOutput {
            success: None,
            failure: None,
            no_crops: None,
            events: Arc::new(Mutex::new(vec![])),
        };
        let logger = CapturingLogger {
            lines: Mutex::new(vec![]),
        };
        let clock = FixedClock {
            today: Date::from_calendar_date(2025, Month::April, 1).unwrap(),
        };
        let gateway = FakeGateway {
            farm: Some(standard_farm()),
            farm_size: None,
            crops: vec![],
            farm_size_error: true,
        };
        let initializer = FakeInitializer {
            result: PlanInitializerResult::failure(vec![]),
        };
        let crop_gateway = FakeCropGateway {
            crops: vec![],
            error: false,
        };
        let mut interactor = PublicPlanCreateInteractor::new(
            &mut output,
            &gateway,
            &crop_gateway,
            &initializer,
            &logger,
            &clock,
            None,
        );
        interactor.call(standard_input());
    }
