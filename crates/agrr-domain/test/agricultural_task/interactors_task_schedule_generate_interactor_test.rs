// Tests for `interactors/task_schedule_generate_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    
    use crate::shared::ports::ClockPort;
    use time::{Date, OffsetDateTime};

    use crate::agricultural_task::constants::schedule_item_types::{
        BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
    };
    use crate::agricultural_task::dtos::TaskScheduleGenerateInput;
    use crate::agricultural_task::dtos::{
        TaskSchedulePlanMutations, TaskScheduleReplaceItem,
    };
    use crate::agricultural_task::gateways::{TaskSchedulePlanContext, TaskScheduleRelatedTask};
    use rust_decimal::Decimal;
    use std::str::FromStr;
    use std::sync::Mutex;

    struct FixedClock {
        now: OffsetDateTime,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.now.date()
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    struct FakeCultivationPlanGateway;

    impl CultivationPlanGateway for FakeCultivationPlanGateway {
        fn within_transaction<F, T>(&self, block: F) -> T
        where
            F: FnOnce() -> T,
        {
            block()
        }
    }

    struct FakeTaskScheduleReadGateway {
        ctx: TaskSchedulePlanContext,
        protectable_items: Vec<crate::agricultural_task::gateways::ProtectableScheduleItemRow>,
    }

    impl TaskScheduleGenerationReadGateway for FakeTaskScheduleReadGateway {
        fn find_plan_row(
            &self,
            _: i64,
        ) -> Result<
            crate::agricultural_task::gateways::TaskSchedulePlanRow,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(crate::agricultural_task::gateways::TaskSchedulePlanRow {
                id: self.ctx.plan.id,
                predicted_weather_data: self.ctx.plan.predicted_weather_data.clone(),
                calculated_planning_start_date: self.ctx.plan.calculated_planning_start_date,
            })
        }

        fn list_field_cultivation_rows(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::TaskScheduleFieldCultivationRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .map(|fc| crate::agricultural_task::gateways::TaskScheduleFieldCultivationRow {
                    id: fc.id,
                    start_date: fc.start_date,
                    crop_id: fc.crop.as_ref().map(|c| c.id),
                })
                .collect())
        }

        fn find_crop_row(
            &self,
            crop_id: i64,
        ) -> Result<
            crate::agricultural_task::gateways::TaskScheduleCropRow,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            let crop = self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .filter_map(|fc| fc.crop.as_ref())
                .find(|c| c.id == crop_id)
                .ok_or_else(|| "crop not found".to_string())?;
            Ok(crate::agricultural_task::gateways::TaskScheduleCropRow {
                id: crop.id,
                name: crop.name.clone(),
            })
        }

        fn list_crop_task_schedule_blueprint_rows(
            &self,
            crop_id: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::TaskScheduleBlueprintRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            let crop = self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .filter_map(|fc| fc.crop.as_ref())
                .find(|c| c.id == crop_id)
                .ok_or_else(|| "crop not found".to_string())?;
            Ok(crop
                .crop_task_schedule_blueprints
                .iter()
                .enumerate()
                .map(|(index, blueprint)| {
                    crate::agricultural_task::gateways::TaskScheduleBlueprintRow {
                        id: (index + 1) as i64,
                        task_type: blueprint.task_type.clone(),
                        gdd_trigger: blueprint.gdd_trigger,
                        gdd_tolerance: blueprint.gdd_tolerance,
                        description: blueprint.description.clone(),
                        stage_name: blueprint.stage_name.clone(),
                        stage_order: blueprint.stage_order,
                        priority: blueprint.priority,
                        source: blueprint.source.clone(),
                        weather_dependency: blueprint.weather_dependency.clone(),
                        time_per_sqm: blueprint.time_per_sqm,
                        amount: blueprint.amount,
                        amount_unit: blueprint.amount_unit.clone(),
                        agricultural_task: blueprint.agricultural_task.clone(),
                    }
                })
                .collect())
        }

        fn build_crop_agrr_requirement(
            &self,
            _: i64,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(serde_json::json!({ "crop": { "name": "stub" } }))
        }

        fn list_protectable_schedule_items(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::ProtectableScheduleItemRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(self.protectable_items.clone())
        }
    }

    #[derive(Debug, Clone)]
    struct MergeReplaceCall {
        _cultivation_plan_id: i64,
        _field_cultivation_id: i64,
        _category: String,
        _generated_at: OffsetDateTime,
        preserved_item_ids: Vec<i64>,
        items: Vec<TaskScheduleReplaceItem>,
    }

    struct CapturingTaskScheduleGateway {
        replaced: Mutex<Vec<ReplaceCall>>,
        merge_replaced: Mutex<Vec<MergeReplaceCall>>,
        cleared: Mutex<Vec<ClearCall>>,
    }

    #[derive(Debug, Clone)]
    struct ReplaceCall {
        _cultivation_plan_id: i64,
        _field_cultivation_id: i64,
        _category: String,
        _generated_at: OffsetDateTime,
        items: Vec<TaskScheduleReplaceItem>,
    }

    #[derive(Debug, Clone)]
    struct ClearCall {
        _cultivation_plan_id: i64,
        _field_cultivation_id: i64,
        _category: String,
    }

    impl CapturingTaskScheduleGateway {
        fn new() -> Self {
            Self {
                replaced: Mutex::new(vec![]),
                merge_replaced: Mutex::new(vec![]),
                cleared: Mutex::new(vec![]),
            }
        }
    }

    impl TaskScheduleGateway for CapturingTaskScheduleGateway {
        fn delete_all_for_field_category(
            &self,
            cultivation_plan_id: i64,
            field_cultivation_id: i64,
            category: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.cleared.lock().unwrap().push(ClearCall {
                _cultivation_plan_id: cultivation_plan_id,
                _field_cultivation_id: field_cultivation_id,
                _category: category.to_string(),
            });
            Ok(())
        }

        fn replace_schedule_for_field_category(
            &self,
            cultivation_plan_id: i64,
            field_cultivation_id: i64,
            category: &str,
            generated_at: OffsetDateTime,
            items: Vec<TaskScheduleReplaceItem>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.replaced.lock().unwrap().push(ReplaceCall {
                _cultivation_plan_id: cultivation_plan_id,
                _field_cultivation_id: field_cultivation_id,
                _category: category.to_string(),
                _generated_at: generated_at,
                items,
            });
            Ok(())
        }

        fn apply_plan_schedule_mutations(
            &self,
            plan_mutations: &TaskSchedulePlanMutations,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            for mutation in &plan_mutations.mutations {
                match mutation {
                    crate::agricultural_task::dtos::TaskScheduleFieldMutation::DeleteAll {
                        field_cultivation_id,
                        category,
                    } => self.delete_all_for_field_category(
                        plan_mutations.cultivation_plan_id,
                        *field_cultivation_id,
                        category,
                    )?,
                    crate::agricultural_task::dtos::TaskScheduleFieldMutation::Replace {
                        field_cultivation_id,
                        category,
                        items,
                    } => self.replace_schedule_for_field_category(
                        plan_mutations.cultivation_plan_id,
                        *field_cultivation_id,
                        category,
                        plan_mutations.generated_at,
                        items.clone(),
                    )?,
                    crate::agricultural_task::dtos::TaskScheduleFieldMutation::MergeReplace {
                        field_cultivation_id,
                        category,
                        preserved_item_ids,
                        items_to_insert,
                    } => {
                        self.merge_replaced.lock().unwrap().push(MergeReplaceCall {
                            _cultivation_plan_id: plan_mutations.cultivation_plan_id,
                            _field_cultivation_id: *field_cultivation_id,
                            _category: category.clone(),
                            _generated_at: plan_mutations.generated_at,
                            preserved_item_ids: preserved_item_ids.clone(),
                            items: items_to_insert.clone(),
                        });
                    }
                }
            }
            Ok(())
        }
    }

    struct StubProgressGateway {
        response: serde_json::Value,
        received: Mutex<Vec<ProgressPayload>>,
    }

    #[derive(Debug, Clone)]
    struct ProgressPayload {
        _crop_id: i64,
        _start_date: Option<Date>,
        weather_data: serde_json::Value,
    }

    impl ProgressGateway for StubProgressGateway {
        fn calculate_progress(
            &self,
            crop: &TaskScheduleCrop,
            start_date: Option<Date>,
            weather_data: &serde_json::Value,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            self.received.lock().unwrap().push(ProgressPayload {
                _crop_id: crop.id,
                _start_date: start_date,
                weather_data: weather_data.clone(),
            });
            Ok(self.response.clone())
        }
    }

    fn dec(s: &str) -> Decimal {
        Decimal::from_str(s).unwrap()
    }

    fn soil_task() -> TaskScheduleRelatedTask {
        TaskScheduleRelatedTask {
            id: 11,
            name: "土壌準備".into(),
            description: Some("soil".into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(dec("0.1")),
        }
    }

    fn mocked_weather_data() -> serde_json::Value {
        serde_json::json!({
            "location": { "latitude": 35.0, "longitude": 135.0, "timezone": "Asia/Tokyo" },
            "data": [
                { "time": "2025-03-20T00:00:00", "temperature_2m_mean": 10.0 },
                { "time": "2025-03-25T00:00:00", "temperature_2m_mean": 12.0 },
                { "time": "2025-04-01T00:00:00", "temperature_2m_mean": 15.0 },
                { "time": "2025-04-05T00:00:00", "temperature_2m_mean": 18.0 },
                { "time": "2025-04-10T00:00:00", "temperature_2m_mean": 20.0 }
            ]
        })
    }

    fn progress_response() -> serde_json::Value {
        serde_json::json!({
            "progress_records": [
                { "date": "2025-04-01T00:00:00", "cumulative_gdd": 0.0 },
                { "date": "2025-04-04T00:00:00", "cumulative_gdd": 120.0 },
                { "date": "2025-04-06T00:00:00", "cumulative_gdd": 165.0 }
            ],
            "total_gdd": 600.0
        })
    }

    fn build_test_fixtures() -> (
        TaskSchedulePlanContext,
        CapturingTaskScheduleGateway,
        FixedClock,
    ) {
        let general_blueprint = TaskScheduleBlueprint {
            task_type: FIELD_WORK.into(),
            gdd_trigger: Some(dec("0.0")),
            gdd_tolerance: Some(dec("5.0")),
            description: None,
            stage_name: Some("土壌準備".into()),
            stage_order: Some(1),
            priority: Some(1),
            source: Some("agrr_schedule".into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(dec("0.1")),
            amount: None,
            amount_unit: None,
            agricultural_task: Some(soil_task()),
        };
        let basal_blueprint = TaskScheduleBlueprint {
            task_type: BASAL_FERTILIZATION.into(),
            gdd_trigger: Some(dec("0.0")),
            gdd_tolerance: Some(dec("5.0")),
            description: None,
            stage_name: Some("定植前".into()),
            stage_order: Some(0),
            priority: Some(1),
            source: Some("agrr_schedule".into()),
            weather_dependency: None,
            time_per_sqm: None,
            amount: None,
            amount_unit: None,
            agricultural_task: Some(TaskScheduleRelatedTask {
                id: 12,
                name: "基肥".into(),
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            }),
        };
        let topdress_blueprint = TaskScheduleBlueprint {
            task_type: TOPDRESS_FERTILIZATION.into(),
            gdd_trigger: Some(dec("160.0")),
            gdd_tolerance: Some(dec("10.0")),
            description: None,
            stage_name: Some("生育期".into()),
            stage_order: Some(2),
            priority: Some(2),
            source: Some("agrr_schedule".into()),
            weather_dependency: None,
            time_per_sqm: None,
            amount: Some(dec("4.0")),
            amount_unit: None,
            agricultural_task: Some(TaskScheduleRelatedTask {
                id: 13,
                name: "追肥".into(),
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            }),
        };

        let crop = TaskScheduleCrop {
            id: 1,
            name: "トマト".into(),
            crop_task_schedule_blueprints: vec![
                general_blueprint,
                basal_blueprint,
                topdress_blueprint,
            ],
        };
        let field_cultivation = TaskScheduleFieldCultivation {
            id: 7,
            crop: Some(crop),
            start_date: Date::from_calendar_date(2025, time::Month::April, 1).ok(),
        };
        let plan = TaskSchedulePlan {
            id: 99,
            predicted_weather_data: mocked_weather_data(),
            field_cultivations: vec![field_cultivation],
            calculated_planning_start_date: None,
        };
        let ctx = TaskSchedulePlanContext { plan };
        let task_schedule_gateway = CapturingTaskScheduleGateway::new();
        let clock = FixedClock {
            now: OffsetDateTime::from_unix_timestamp(1_735_689_600).unwrap(),
        };
        (ctx, task_schedule_gateway, clock)
    }

    // Ruby: test "generate! produces general + fertilizer schedules with blueprint-derived items"
    #[test]
    fn generate_produces_general_and_fertilizer_schedules() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        interactor.call(TaskScheduleGenerateInput::new(99)).expect("call");

        let replaced = task_schedule_gateway.merge_replaced.lock().unwrap();
        assert_eq!(replaced.len(), 2);
        let general = replaced.iter().find(|r| r._category == "general").unwrap();
        let fertilizer = replaced.iter().find(|r| r._category == "fertilizer").unwrap();
        assert_eq!(general.items.len(), 1);
        assert_eq!(general.items[0].task_type, FIELD_WORK);
        assert_eq!(general.items[0].agricultural_task_id, Some(11));
        assert_eq!(general.items[0].scheduled_date, Date::from_calendar_date(2025, time::Month::April, 1).unwrap());
        assert_eq!(fertilizer.items.len(), 2);
        assert_eq!(fertilizer.items.last().unwrap().scheduled_date, Date::from_calendar_date(2025, time::Month::April, 6).unwrap());
    }

    // Ruby: test "generate! raises when crop has no blueprints"
    #[test]
    fn generate_raises_blueprint_missing_when_no_blueprints() {
        let (mut ctx, task_schedule_gateway, clock) = build_test_fixtures();
        if let Some(fc) = ctx.plan.field_cultivations.first_mut() {
            if let Some(crop) = fc.crop.as_mut() {
                crop.crop_task_schedule_blueprints.clear();
            }
        }
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.call(TaskScheduleGenerateInput::new(99)).unwrap_err();
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
            crate::agricultural_task::task_schedule_sync_error_keys::MISSING_CROP_BLUEPRINTS.to_string()
        );
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_crop_id(err.as_ref()),
            Some(1)
        );
    }

    #[test]
    fn generate_raises_general_blueprint_missing_when_only_fertilizer_blueprints() {
        let (mut ctx, task_schedule_gateway, clock) = build_test_fixtures();
        if let Some(fc) = ctx.plan.field_cultivations.first_mut() {
            if let Some(crop) = fc.crop.as_mut() {
                crop.crop_task_schedule_blueprints.retain(|b| {
                    b.task_type == BASAL_FERTILIZATION || b.task_type == TOPDRESS_FERTILIZATION
                });
            }
        }
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.call(TaskScheduleGenerateInput::new(99)).unwrap_err();
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
            crate::agricultural_task::task_schedule_sync_error_keys::MISSING_GENERAL_BLUEPRINTS.to_string()
        );
    }

    // Ruby: test "generate! raises ProgressDataMissingError when progress has no records"
    #[test]
    fn generate_raises_progress_missing_when_no_records() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: serde_json::json!({ "progress_records": [] }),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.call(TaskScheduleGenerateInput::new(99)).unwrap_err();
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
            crate::agricultural_task::task_schedule_sync_error_keys::EMPTY_GDD_PROGRESS.to_string()
        );
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_crop_id(err.as_ref()),
            Some(1)
        );
    }

    // Ruby: test "progress gateway receives weather data filtered from the start date"
    #[test]
    fn progress_gateway_receives_filtered_weather() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        interactor.call(TaskScheduleGenerateInput::new(99)).expect("call");
        let payload = progress_gateway.received.lock().unwrap().last().unwrap().clone();
        let times: Vec<_> = payload
            .weather_data
            .get("data")
            .and_then(|v| v.as_array())
            .unwrap()
            .iter()
            .filter_map(|e| e.get("time").and_then(|t| t.as_str()))
            .collect();
        assert!(!times.is_empty());
        let start = Date::from_calendar_date(2025, time::Month::April, 1).unwrap();
        assert!(times.iter().all(|t| safe_parse_date(t).unwrap() >= start));
    }

    // Ruby: test "generate! raises GddTriggerMissingError when a blueprint has no gdd trigger"
    #[test]
    fn generate_raises_gdd_trigger_missing() {
        let (mut ctx, task_schedule_gateway, clock) = build_test_fixtures();
        if let Some(fc) = ctx.plan.field_cultivations.first_mut() {
            if let Some(crop) = fc.crop.as_mut() {
                crop.crop_task_schedule_blueprints[0].gdd_trigger = None;
            }
        }
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items: vec![],
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.call(TaskScheduleGenerateInput::new(99)).unwrap_err();
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
            crate::agricultural_task::task_schedule_sync_error_keys::MISSING_GDD_TRIGGER.to_string()
        );
        assert_eq!(
            crate::agricultural_task::task_schedule_sync_error_crop_id(err.as_ref()),
            Some(1)
        );
    }

    #[test]
    fn generate_preserves_manual_and_work_record_items_in_merge_replace() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let field_cultivation_id = ctx.plan.field_cultivations[0].id;
        let protectable_items = vec![
            crate::agricultural_task::gateways::ProtectableScheduleItemRow {
                id: 501,
                field_cultivation_id,
                category: "general".into(),
                source: Some("manual_entry".into()),
                agricultural_task_id: None,
                stage_order: None,
                has_work_record: false,
            },
            crate::agricultural_task::gateways::ProtectableScheduleItemRow {
                id: 502,
                field_cultivation_id,
                category: "general".into(),
                source: Some("agrr_schedule".into()),
                agricultural_task_id: Some(11),
                stage_order: Some(1),
                has_work_record: true,
            },
        ];
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway {
            ctx,
            protectable_items,
        };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        interactor.call(TaskScheduleGenerateInput::new(99)).expect("call");

        let merged = task_schedule_gateway.merge_replaced.lock().unwrap();
        let general = merged.iter().find(|r| r._category == "general").unwrap();
        assert_eq!(vec![501, 502], general.preserved_item_ids);
        assert!(
            general.items.is_empty(),
            "matching agrr item must be suppressed when preserved item shares match key"
        );
    }
