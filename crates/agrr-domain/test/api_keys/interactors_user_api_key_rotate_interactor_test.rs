// Tests for `interactors/user_api_key_rotate_interactor.rs` (Ruby parity under test/domain/api_keys/).

    use crate::api_keys::dtos::{UserApiKeyRotationError, UserApiKeyRotationOutput};
    use std::sync::{Arc, Mutex};

    #[derive(Default, Clone)]
    struct RecordingState {
        success_api_key: Option<String>,
        failure_message: Option<String>,
    }

    struct RecordingPort(Arc<Mutex<RecordingState>>);

    impl UserApiKeyRotateOutputPort for RecordingPort {
        fn on_success(&mut self, api_key: String) {
            let mut state = self.0.lock().unwrap();
            state.success_api_key = Some(api_key);
            state.failure_message = None;
        }

        fn on_failure(&mut self, message: String) {
            let mut state = self.0.lock().unwrap();
            state.failure_message = Some(message);
            state.success_api_key = None;
        }
    }

    struct StubGateway {
        result: UserApiKeyRotationOutput,
        calls: Arc<Mutex<Vec<(i64, bool)>>>,
    }

    impl UserApiKeyRotationGateway for StubGateway {
        fn rotate(&self, user_id: i64, regenerate: bool) -> UserApiKeyRotationOutput {
            self.calls.lock().unwrap().push((user_id, regenerate));
            self.result.clone()
        }
    }

    fn run(
        result: UserApiKeyRotationOutput,
        user_id: i64,
        regenerate: bool,
    ) -> (RecordingState, Vec<(i64, bool)>) {
        let state = Arc::new(Mutex::new(RecordingState::default()));
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut interactor = UserApiKeyRotateInteractor::new(
            Box::new(RecordingPort(Arc::clone(&state))),
            StubGateway {
                result,
                calls: Arc::clone(&calls),
            },
        );
        interactor.call(user_id, regenerate);
        let recorded_state = state.lock().unwrap().clone();
        let recorded_calls = calls.lock().unwrap().clone();
        (recorded_state, recorded_calls)
    }

    #[test]
    fn forwards_user_id_and_regenerate_to_gateway() {
        let (_, calls) = run(
            UserApiKeyRotationOutput::new(true, Some("k".into()), None),
            42,
            true,
        );
        assert_eq!(calls, vec![(42, true)]);
    }

    #[test]
    fn not_found_emits_user_not_found_failure() {
        let (state, _) = run(
            UserApiKeyRotationOutput::new(
                false,
                None,
                Some(UserApiKeyRotationError::NotFound),
            ),
            1,
            false,
        );
        assert_eq!(state.failure_message.as_deref(), Some("User not found"));
        assert!(state.success_api_key.is_none());
    }

    #[test]
    fn ok_true_emits_success_with_api_key() {
        let (state, _) = run(
            UserApiKeyRotationOutput::new(true, Some("new-secret".into()), None),
            9,
            false,
        );
        assert_eq!(state.success_api_key.as_deref(), Some("new-secret"));
        assert!(state.failure_message.is_none());
    }

    #[test]
    fn ok_false_generate_emits_generate_failure_message() {
        let (state, _) = run(
            UserApiKeyRotationOutput::new(false, None, None),
            1,
            false,
        );
        assert_eq!(
            state.failure_message.as_deref(),
            Some("Failed to generate API key")
        );
    }

    #[test]
    fn ok_false_regenerate_emits_regenerate_failure_message() {
        let (state, _) = run(
            UserApiKeyRotationOutput::new(false, None, None),
            1,
            true,
        );
        assert_eq!(
            state.failure_message.as_deref(),
            Some("Failed to regenerate API key")
        );
    }

    #[test]
    fn not_found_takes_precedence_over_ok_false() {
        let (state, _) = run(
            UserApiKeyRotationOutput::new(
                false,
                None,
                Some(UserApiKeyRotationError::NotFound),
            ),
            1,
            true,
        );
        assert_eq!(state.failure_message.as_deref(), Some("User not found"));
    }
