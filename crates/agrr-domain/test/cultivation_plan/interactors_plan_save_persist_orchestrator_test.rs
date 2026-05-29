// Tests for `interactors/plan_save_persist_orchestrator.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;

    struct MockFarmInteractor {
        expected_user_id: i64,
        expected_reference_farm_id: i64,
        output: PlanSaveEnsureUserFarmOutput,
    }

    impl PlanSaveEnsureUserFarmPort for MockFarmInteractor {
        fn execute(
            &self,
            input: PlanSaveEnsureUserFarmInput,
        ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(input.user_id, self.expected_user_id);
            assert_eq!(input.reference_farm_id, self.expected_reference_farm_id);
            Ok(self.output.clone())
        }
    }

    // Ruby: test "ensure_user_farm delegates to interactor with farm_id from session hash"
    #[test]
    fn ensure_user_farm_delegates_with_farm_id_from_session_hash() {
        let mut map = BTreeMap::new();
        map.insert("farm_id".into(), json!(10));
        let interactor = MockFarmInteractor {
            expected_user_id: 5,
            expected_reference_farm_id: 10,
            output: PlanSaveEnsureUserFarmOutput {
                farm_id: 77,
                farm_reused: false,
                farm_region: Some("jp".into()),
            },
        };
        let orchestrator = PlanSavePersistOrchestrator::new(&interactor);
        let out = orchestrator
            .ensure_user_farm(5, PlanSaveSessionRef::Json(&map))
            .unwrap();
        assert_eq!(out.farm_id, 77);
    }

    // Ruby: test "ensure_user_farm reads farm_id from PublicPlanSaveSessionData"
    #[test]
    fn ensure_user_farm_reads_farm_id_from_public_plan_save_session_data() {
        let interactor = MockFarmInteractor {
            expected_user_id: 3,
            expected_reference_farm_id: 12,
            output: PlanSaveEnsureUserFarmOutput {
                farm_id: 1,
                farm_reused: true,
                farm_region: Some("jp".into()),
            },
        };
        let session = PublicPlanSaveSessionData::new(1, Some(12), vec![], None);
        PlanSavePersistOrchestrator::new(&interactor)
            .ensure_user_farm(3, PlanSaveSessionRef::Dto(&session))
            .unwrap();
    }
