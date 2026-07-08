// Tests for `interactors/task_schedule_item_skip_interactor.rs`

    use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
    use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
    use crate::cultivation_plan::gateways::CultivationPlanGateway;
    use crate::cultivation_plan::gateways::TaskScheduleItemMutationGateway;
    use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
    use crate::shared::exceptions::RecordNotFoundError;
    use crate::shared::ports::ClockPort;
    use serde_json::Value;
    use std::collections::BTreeMap;
    use std::sync::{Arc, Mutex};
    use time::macros::datetime;
    use time::OffsetDateTime;

    struct FakeClock {
        now_val: OffsetDateTime,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            self.now_val.date()
        }

        fn now(&self) -> OffsetDateTime {
            self.now_val
        }
    }

    struct SpyOutput {
        events: Arc<Mutex<Vec<String>>>,
        payload: Arc<Mutex<Option<Value>>>,
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
            _: BTreeMap<String, Vec<String>>,
            _: &str,
        ) {
            self.events.lock().unwrap().push("record_invalid".into());
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

    struct StubMutationGateway {
        skip_payload: Value,
        unskip_payload: Value,
        skip_calls: Arc<Mutex<Vec<(i64, i64, OffsetDateTime)>>>,
        unskip_calls: Arc<Mutex<Vec<(i64, i64)>>>,
        skip_err: Option<RecordNotFoundError>,
        unskip_err: Option<RecordNotFoundError>,
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

        fn find_agricultural_task_for_mutation(
            &self,
            _: Option<i64>,
        ) -> Result<
            Option<crate::cultivation_plan::dtos::TaskScheduleAgriculturalTaskSnapshot>,
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

        fn skip_item_for_plan(
            &self,
            plan_id: i64,
            item_id: i64,
            cancelled_at: OffsetDateTime,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            self.skip_calls.lock().unwrap().push((plan_id, item_id, cancelled_at));
            if let Some(_) = self.skip_err {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.skip_payload.clone())
        }

        fn unskip_item_for_plan(
            &self,
            plan_id: i64,
            item_id: i64,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            self.unskip_calls.lock().unwrap().push((plan_id, item_id));
            if let Some(_) = self.unskip_err {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.unskip_payload.clone())
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

    #[test]
    fn skips_item_after_private_plan_access_check() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let payload_slot = Arc::new(Mutex::new(None));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::clone(&payload_slot),
        };
        let skip_calls = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubMutationGateway {
            skip_payload: serde_json::json!({
                "id": 9,
                "status": "skipped",
                "cancelled_at": "2026-03-01T12:00:00Z"
            }),
            unskip_payload: Value::Null,
            skip_calls: Arc::clone(&skip_calls),
            unskip_calls: Arc::new(Mutex::new(Vec::new())),
            skip_err: None,
            unskip_err: None,
        };
        let clock = FakeClock {
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemSkipInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_skip_rescuing(1, 2, 9).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
        let calls = skip_calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, 2);
        assert_eq!(calls[0].1, 9);
        assert_eq!(calls[0].2, datetime!(2026-03-01 12:00 UTC));
    }

    #[test]
    fn unskips_item_after_private_plan_access_check() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
        };
        let unskip_calls = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubMutationGateway {
            skip_payload: Value::Null,
            unskip_payload: serde_json::json!({
                "id": 9,
                "status": "planned",
                "cancelled_at": null
            }),
            skip_calls: Arc::new(Mutex::new(Vec::new())),
            unskip_calls: Arc::clone(&unskip_calls),
            skip_err: None,
            unskip_err: None,
        };
        let clock = FakeClock {
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemSkipInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_unskip_rescuing(1, 2, 9).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["success".to_string()]);
        let calls = unskip_calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0], (2, 9));
    }

    #[test]
    fn dispatches_not_found_when_private_plan_access_denied() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
        };
        let gateway = StubMutationGateway {
            skip_payload: Value::Null,
            unskip_payload: Value::Null,
            skip_calls: Arc::new(Mutex::new(Vec::new())),
            unskip_calls: Arc::new(Mutex::new(Vec::new())),
            skip_err: None,
            unskip_err: None,
        };
        let clock = FakeClock {
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(99),
        };
        let mut interactor =
            TaskScheduleItemSkipInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_skip_rescuing(1, 2, 9).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
        assert!(gateway.skip_calls.lock().unwrap().is_empty());
    }

    #[test]
    fn dispatches_not_found_when_gateway_skip_raises_record_not_found() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: Arc::clone(&events),
            payload: Arc::new(Mutex::new(None)),
        };
        let gateway = StubMutationGateway {
            skip_payload: Value::Null,
            unskip_payload: Value::Null,
            skip_calls: Arc::new(Mutex::new(Vec::new())),
            unskip_calls: Arc::new(Mutex::new(Vec::new())),
            skip_err: Some(RecordNotFoundError),
            unskip_err: None,
        };
        let clock = FakeClock {
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1),
        };
        let mut interactor =
            TaskScheduleItemSkipInteractor::new(&mut output, &plan_gateway, &gateway, &clock);

        interactor.call_skip_rescuing(1, 2, 9).unwrap();

        assert_eq!(&*events.lock().unwrap(), &["not_found".to_string()]);
    }
