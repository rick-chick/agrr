// Tests for `interactors/advance_cultivation_plan_phase_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::{CultivationPlanCreateAttrs, CultivationPlanPhaseName};
    
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

    use crate::cultivation_plan::entities::FieldCultivationEntity;
    use crate::shared::user::User;
    use serde_json::Value;
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct StubGateway {
        plan: CultivationPlanEntity,
        field_cultivations: Vec<FieldCultivationEntity>,
        updates: Arc<Mutex<Vec<HashMap<String, String>>>>,
    }

    impl CultivationPlanGateway for StubGateway {
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
            attrs: HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.updates.lock().unwrap().push(attrs);
            Ok(self.plan.clone())
        }

        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.field_cultivations.clone())
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
            _: &User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(
            &self,
            _: i64,
            _: &User,
            _: &str,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyBroadcast {
        called: Arc<Mutex<bool>>,
    }

    impl CultivationPlanPhaseBroadcastPort for SpyBroadcast {
        fn broadcast_phase_update(&self, _: i64, _: &str, _: &Value) {
            *self.called.lock().unwrap() = true;
        }
    }

    fn plan_entity() -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 1,
            farm_id: 1,
            user_id: 1,
            total_area: 100.0,
            plan_type: "public".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: Some("optimizing".into()),
            session_id: None,
            display_name: None,
            optimization_phase: Some("fetching_weather".into()),
            optimization_phase_message: Some("取得中".into()),
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    fn field_cultivation() -> FieldCultivationEntity {
        FieldCultivationEntity {
            id: 10,
            cultivation_plan_id: 1,
            cultivation_plan_field_id: Some(1),
            cultivation_plan_crop_id: Some(1),
            area: Some(50.0),
            status: Some("completed".into()),
        }
    }

    // Ruby: test "call updates plan and broadcasts when phase requires broadcast"
    #[test]
    fn call_updates_plan_and_broadcasts_when_phase_requires_broadcast() {
        let updates = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubGateway {
            plan: plan_entity(),
            field_cultivations: vec![field_cultivation()],
            updates: Arc::clone(&updates),
        };
        let called = Arc::new(Mutex::new(false));
        let broadcast = SpyBroadcast {
            called: Arc::clone(&called),
        };
        let interactor = AdvanceCultivationPlanPhaseInteractor::new(
            &gateway,
            &StubTranslator,
            &broadcast,
        );

        interactor
            .call(AdvanceCultivationPlanPhaseInput {
                plan_id: 1,
                phase_name: CultivationPlanPhaseName::PhaseFetchingWeather,
                channel_class: Some("TestChannel".into()),
                failure_subphase: None,
            })
            .unwrap();

        assert!(*called.lock().unwrap());
        let recorded = updates.lock().unwrap();
        assert!(recorded.iter().any(|a| a.get("optimization_phase") == Some(&"fetching_weather".to_string())));
        assert!(recorded.iter().any(|a| a.get("status") == Some(&"completed".to_string())));
    }

    // Ruby: test "call updates plan and broadcasts when start_optimizing"
    #[test]
    fn call_broadcasts_when_start_optimizing() {
        let updates = Arc::new(Mutex::new(Vec::new()));
        let gateway = StubGateway {
            plan: plan_entity(),
            field_cultivations: vec![],
            updates: Arc::clone(&updates),
        };
        let called = Arc::new(Mutex::new(false));
        let broadcast = SpyBroadcast {
            called: Arc::clone(&called),
        };
        let interactor = AdvanceCultivationPlanPhaseInteractor::new(
            &gateway,
            &StubTranslator,
            &broadcast,
        );

        interactor
            .call(AdvanceCultivationPlanPhaseInput {
                plan_id: 1,
                phase_name: CultivationPlanPhaseName::StartOptimizing,
                channel_class: Some("TestChannel".into()),
                failure_subphase: None,
            })
            .unwrap();

        assert!(*called.lock().unwrap());
    }
