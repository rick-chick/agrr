// Tests for `interactors/agricultural_task_destroy_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::dtos::UndoEntity;
    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::agricultural_task::gateways::SoftDeleteUndoResult;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct KeyTranslator;
    impl TranslatorPort for KeyTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(
            &self,
            _: time::Date,
            _: Option<&str>,
            _: &TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct DestroyGateway {
        task: AgriculturalTaskEntity,
        deny_delete: bool,
    }

    impl AgriculturalTaskGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.task.clone())
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            auto_hide_after: i64,
            toast_message: &str,
        ) -> Result<SoftDeleteUndoResult, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(auto_hide_after, 5000);
            assert_eq!(toast_message, "agricultural_tasks.undo.toast");
            if self.deny_delete {
                unimplemented!("must not be called")
            }
            Ok(SoftDeleteUndoResult::Success {
                undo: UndoEntity {
                    raw: serde_json::json!({"id": 1}),
                },
            })
        }

        fn list_user_owned_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_tasks(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_user_and_reference_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_agricultural_task_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_by_reference_and_name(
            &self,
            _: &str,
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_user_id_and_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create(
            &self,
            _: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn within_transaction<F, T>(&self, block: F) -> T
        where
            F: FnOnce() -> T,
        {
            block()
        }
    }

    struct SpyDestroy {
        success: bool,
        failure: Option<DestroyFailure>,
    }

    impl AgriculturalTaskDestroyOutputPort for SpyDestroy {
        fn on_success(&mut self, _: AgriculturalTaskDestroyOutput) {
            self.success = true;
        }

        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_task(user_id: i64, name: &str) -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(22),
            user_id: Some(user_id),
            name: name.into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    // Ruby: test "calls on_success when gateway returns success"
    #[test]
    fn calls_on_success_when_gateway_returns_success() {
        let gateway = DestroyGateway {
            task: sample_task(10, "除草"),
            deny_delete: false,
        };
        let mut output = SpyDestroy {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let translator = KeyTranslator;
        let mut interactor = AgriculturalTaskDestroyInteractor::new(
            &mut output,
            10,
            &gateway,
            &translator,
            &lookup,
        );
        interactor.call(22).expect("handled");
        assert!(output.success);
        assert!(output.failure.is_none());
    }

    // Ruby: test "calls on_failure with policy exception when permission is denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_is_denied() {
        let gateway = DestroyGateway {
            task: sample_task(99, "作業"),
            deny_delete: true,
        };
        let mut output = SpyDestroy {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let translator = KeyTranslator;
        let mut interactor = AgriculturalTaskDestroyInteractor::new(
            &mut output,
            10,
            &gateway,
            &translator,
            &lookup,
        );
        interactor.call(22).expect("handled");
        assert!(!output.success);
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
