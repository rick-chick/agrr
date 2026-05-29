// Tests for `interactors/task_schedule_item_complete_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
    use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
    use crate::shared::exceptions::RecordInvalidError;
    use std::sync::{Arc, Mutex};
    use time::macros::{date, datetime};
    use time::{Date, OffsetDateTime};

    struct FakeClock {
        today_val: Date,
        now_val: OffsetDateTime,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            self.today_val
        }

        fn now(&self) -> OffsetDateTime {
            self.now_val
        }
    }

    struct SpyOutput {
        events: Arc<Mutex<Vec<String>>>,
        payload: Arc<Mutex<Option<Value>>>,
        errors: Arc<Mutex<Option<BTreeMap<String, Vec<String>>>>>,
    }

    impl TaskScheduleItemMutationOutputPort for SpyOutput {
        fn on_created(&mut self, _: Value) {
            self.events.lock().unwrap().push("created".into());
        }

        fn on_success(&mut self, item_payload: Value) {
            self.events.lock().unwrap().push("success".into());
            *self.payload.lock().unwrap() = Some(item_payload);
        }

        fn on_record_invalid(
            &mut self,
            errors: BTreeMap<String, Vec<String>>,
            _: &str,
        ) {
            self.events.lock().unwrap().push("record_invalid".into());
            *self.errors.lock().unwrap() = Some(errors);
        }

        fn on_not_found(&mut self) {
            self.events.lock().unwrap().push("not_found".into());
        }
    }

    struct StubPlanGateway {
        plan: CultivationPlanEntity,
    }

    impl CultivationPlanGateway for StubPlanGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.plan.clone())
        }

        fn create(
            &self,
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: std::collections::HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            block()
        }

        fn private_owned_plan_display_name(
            &self,
            _: &crate::shared::user::User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(
            &self,
            _: i64,
            _: &crate::shared::user::User,
            _: &str,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    enum CompleteOutcome {
        Ok(Value),
        ErrRecordInvalid(RecordInvalidError),
        ErrNotFound,
    }

    struct StubMutationGateway {
        complete_outcome: CompleteOutcome,
        complete_calls: Arc<Mutex<Vec<(i64, i64, Date, Option<String>, OffsetDateTime)>>>,
    }

    impl TaskScheduleItemMutationGateway for StubMutationGateway {
        fn find_field_cultivation_for_create(
            &self,
            _: i64,
            _: i64,
        ) -> Result<
            crate::cultivation_plan::dtos::TaskScheduleFieldCultivationSnapshot,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_crop_task_template_for_mutation(
            &self,
            _: Option<i64>,
        ) -> Result<
            Option<crate::cultivation_plan::dtos::TaskScheduleCropTaskTemplateSnapshot>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_item_amount_snapshot(
            &self,
            _: i64,
            _: i64,
        ) -> Result<
            crate::cultivation_plan::dtos::TaskScheduleItemAmountSnapshot,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn create(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_item_for_plan(
            &self,
            _: i64,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn complete_item_for_plan(
            &self,
            plan_id: i64,
            item_id: i64,
            actual_date: Date,
            actual_notes: Option<&str>,
            completed_at: OffsetDateTime,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            self.complete_calls.lock().unwrap().push((
                plan_id,
                item_id,
                actual_date,
                actual_notes.map(str::to_string),
                completed_at,
            ));
            match &self.complete_outcome {
                CompleteOutcome::Ok(v) => Ok(v.clone()),
                CompleteOutcome::ErrRecordInvalid(e) => Err(Box::new(RecordInvalidError::new(
                    e.detail_message().map(str::to_string),
                    e.errors.clone(),
                ))),
                CompleteOutcome::ErrNotFound => Err(Box::new(RecordNotFoundError)),
            }
        }

        fn deletion_undo_schedule_row_for_item(
            &self,
            _: i64,
            _: i64,
        ) -> Result<
            crate::cultivation_plan::dtos::TaskScheduleItemDeletionUndoScheduleRow,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    fn private_plan(user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 2,
            farm_id: 1,
            user_id,
            total_area: 0.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: None,
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "completes item after private plan access check"
    #[test]
    fn completes_item_after_private_plan_access_check() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let payload_slot = Arc::new(Mutex::new(None));
        let errors = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::clone(&payload_slot),
            errors,
        };
        let complete_calls = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubMutationGateway {
            complete_outcome: CompleteOutcome::Ok(serde_json::json!({"id": 9, "status": "completed"})),
            complete_calls: Arc::clone(&complete_calls),
        };
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemCompleteInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        let mut params = BTreeMap::new();
        params.insert("actual_date".into(), Value::String("2026-04-10".into()));
        params.insert("notes".into(), Value::String("実施メモ".into()));

        interactor
            .call_rescuing(1, 2, 9, &params)
            .unwrap();

        assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
        let calls = complete_calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, 2);
        assert_eq!(calls[0].1, 9);
        assert_eq!(calls[0].2, date!(2026-04-10));
        assert_eq!(calls[0].3.as_deref(), Some("実施メモ"));
        assert_eq!(calls[0].4, datetime!(2026-03-01 12:00 UTC));
    }

    // Ruby: test "dispatches not_found when private plan access denied"
    #[test]
    fn dispatches_not_found_when_private_plan_access_denied() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
            errors: Arc::new(Mutex::new(None)),
        };
        let complete_calls = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubMutationGateway {
            complete_outcome: CompleteOutcome::Ok(Value::Null),
            complete_calls: Arc::clone(&complete_calls),
        };
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(99),
        };
        let mut interactor =
            TaskScheduleItemCompleteInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_rescuing(1, 2, 9, &BTreeMap::new()).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
        assert!(complete_calls.lock().unwrap().is_empty());
    }

    // Ruby: test "dispatches record_invalid when completion params have invalid date"
    #[test]
    fn dispatches_record_invalid_when_completion_params_have_invalid_date() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let errors = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
            errors: Arc::clone(&errors),
        };
        let complete_calls = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubMutationGateway {
            complete_outcome: CompleteOutcome::Ok(Value::Null),
            complete_calls: Arc::clone(&complete_calls),
        };
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemCompleteInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        let mut params = BTreeMap::new();
        params.insert("actual_date".into(), Value::String("bogus".into()));

        interactor.call_rescuing(1, 2, 9, &params).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["record_invalid".to_string()]);
        assert!(complete_calls.lock().unwrap().is_empty());
        assert!(
            errors
                .lock()
                .unwrap()
                .as_ref()
                .unwrap()
                .contains_key("actual_date")
        );
    }

    // Ruby: test "dispatches record_invalid when gateway complete raises RecordInvalid"
    #[test]
    fn dispatches_record_invalid_when_gateway_complete_raises_record_invalid() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let errors = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
            errors: Arc::clone(&errors),
        };
        let mut validation = crate::shared::validation::ValidationErrors::new();
        validation.add("actual_date", "blank");
        let gateway = StubMutationGateway {
            complete_outcome: CompleteOutcome::ErrRecordInvalid(RecordInvalidError::new(
                Some("invalid".into()),
                Some(validation),
            )),
            complete_calls: Arc::new(Mutex::new(Vec::new())),
        };
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemCompleteInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_rescuing(1, 2, 9, &BTreeMap::new()).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["record_invalid".to_string()]);
        assert!(
            errors
                .lock()
                .unwrap()
                .as_ref()
                .unwrap()
                .contains_key("actual_date")
        );
    }

    // Ruby: test "dispatches not_found when gateway complete raises RecordNotFound"
    #[test]
    fn dispatches_not_found_when_gateway_complete_raises_record_not_found() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
            errors: Arc::new(Mutex::new(None)),
        };
        let gateway = StubMutationGateway {
            complete_outcome: CompleteOutcome::ErrNotFound,
            complete_calls: Arc::new(Mutex::new(Vec::new())),
        };
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemCompleteInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_rescuing(1, 2, 9, &BTreeMap::new()).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
    }
