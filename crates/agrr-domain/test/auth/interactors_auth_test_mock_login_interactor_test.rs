// Tests for `interactors/auth_test_mock_login_interactor.rs` (Ruby parity under test/domain/auth/).

    use crate::auth::dtos::AuthTestMockLoginPersistResult;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use time::macros::datetime;

    struct FakeGateway {
        result: AuthTestMockLoginPersistResult,
        persist_calls: AtomicUsize,
    }

    impl AuthTestLoginGateway for FakeGateway {
        fn persist_mock_user_and_session(
            &self,
            _input_dto: &AuthTestMockLoginInput,
        ) -> AuthTestMockLoginPersistResult {
            self.persist_calls.fetch_add(1, Ordering::SeqCst);
            self.result.clone()
        }
    }

    struct FakeAppender;

    impl OauthConversionUrlAppenderPort for FakeAppender {
        fn append(&self, pending_return_to: &str) -> String {
            format!("appended:{pending_return_to}")
        }
    }

    #[derive(Default)]
    struct RecordingPort {
        environment_forbidden: usize,
        missing_mock: usize,
        create_failed: usize,
        success_process_saved_plan: usize,
        success_root: usize,
        last_root_session_id: Option<String>,
        last_root_user_name: Option<String>,
    }

    impl AuthTestMockLoginOutputPort for RecordingPort {
        fn on_environment_forbidden(&mut self) {
            self.environment_forbidden += 1;
        }
        fn on_missing_mock(&mut self) {
            self.missing_mock += 1;
        }
        fn on_create_failed(&mut self, _error_messages: Vec<String>) {
            self.create_failed += 1;
        }
        fn on_success_process_saved_plan(
            &mut self,
            _session_id: &str,
            _expires_at: time::OffsetDateTime,
        ) {
            self.success_process_saved_plan += 1;
        }
        fn on_success_return_to(
            &mut self,
            _url: &str,
            _session_id: &str,
            _expires_at: time::OffsetDateTime,
            _user_name: &str,
        ) {
        }
        fn on_success_root(
            &mut self,
            session_id: &str,
            _expires_at: time::OffsetDateTime,
            user_name: &str,
        ) {
            self.success_root += 1;
            self.last_root_session_id = Some(session_id.to_string());
            self.last_root_user_name = Some(user_name.to_string());
        }
    }

    fn default_input() -> AuthTestMockLoginInput {
        AuthTestMockLoginInput::new(
            "gid",
            "e",
            "n",
            "x",
            false,
            false,
            None::<String>,
            false,
        )
    }

    // Ruby: test "environment not allowed"
    #[test]
    fn environment_not_allowed() {
        let gateway = FakeGateway {
            result: AuthTestMockLoginPersistResult::success("U", "sess", datetime!(2026-01-01 0:00 UTC)),
            persist_calls: AtomicUsize::new(0),
        };
        let mut port = RecordingPort::default();
        let appender = FakeAppender;
        let mut interactor = AuthTestMockLoginInteractor::new(&mut port, &gateway, &appender);

        interactor.call(&default_input(), false);

        assert_eq!(port.environment_forbidden, 1);
        assert_eq!(gateway.persist_calls.load(Ordering::SeqCst), 0);
    }

    // Ruby: test "blank google_id triggers missing mock"
    #[test]
    fn blank_google_id_triggers_missing_mock() {
        let gateway = FakeGateway {
            result: AuthTestMockLoginPersistResult::success("U", "sess", datetime!(2026-01-01 0:00 UTC)),
            persist_calls: AtomicUsize::new(0),
        };
        let mut port = RecordingPort::default();
        let appender = FakeAppender;
        let mut interactor = AuthTestMockLoginInteractor::new(&mut port, &gateway, &appender);
        let input = AuthTestMockLoginInput::new(
            "",
            "e",
            "n",
            "x",
            false,
            false,
            None::<String>,
            false,
        );

        interactor.call(&input, true);

        assert_eq!(port.missing_mock, 1);
        assert_eq!(gateway.persist_calls.load(Ordering::SeqCst), 0);
    }

    // Ruby: test "success without extras calls on_success_root"
    #[test]
    fn success_without_extras_calls_on_success_root() {
        let expires = datetime!(2026-05-08 12:00 UTC);
        let gateway = FakeGateway {
            result: AuthTestMockLoginPersistResult::success("U", "sess", expires),
            persist_calls: AtomicUsize::new(0),
        };
        let mut port = RecordingPort::default();
        let appender = FakeAppender;
        let mut interactor = AuthTestMockLoginInteractor::new(&mut port, &gateway, &appender);

        interactor.call(&default_input(), true);

        assert_eq!(port.success_root, 1);
        assert_eq!(port.last_root_session_id.as_deref(), Some("sess"));
        assert_eq!(port.last_root_user_name.as_deref(), Some("U"));
        assert_eq!(gateway.persist_calls.load(Ordering::SeqCst), 1);
    }

    // Ruby: test "success with stashed public plan"
    #[test]
    fn success_with_stashed_public_plan() {
        let expires = datetime!(2026-01-01 0:00 UTC);
        let gateway = FakeGateway {
            result: AuthTestMockLoginPersistResult::success("U", "s", expires),
            persist_calls: AtomicUsize::new(0),
        };
        let mut port = RecordingPort::default();
        let appender = FakeAppender;
        let mut interactor = AuthTestMockLoginInteractor::new(&mut port, &gateway, &appender);
        let input = AuthTestMockLoginInput::new(
            "gid",
            "e",
            "n",
            "x",
            false,
            true,
            None::<String>,
            false,
        );

        interactor.call(&input, true);

        assert_eq!(port.success_process_saved_plan, 1);
        assert_eq!(port.success_root, 0);
    }
