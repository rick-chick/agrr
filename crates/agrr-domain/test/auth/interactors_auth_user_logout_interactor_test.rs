// Tests for `interactors/auth_user_logout_interactor.rs` (Ruby parity under test/domain/auth/).

    use std::sync::Mutex;

    struct FakeRevocationGateway {
        deleted_user_ids: Mutex<Vec<i64>>,
    }

    impl UserSessionRevocationGateway for FakeRevocationGateway {
        fn delete_all_sessions_for_user(&self, user_id: i64) {
            self.deleted_user_ids.lock().unwrap().push(user_id);
        }
    }

    #[derive(Default)]
    struct RecordingPort {
        success: usize,
        not_logged_in: usize,
    }

    impl AuthUserLogoutOutputPort for RecordingPort {
        fn on_success(&mut self) {
            self.success += 1;
        }
        fn on_not_logged_in(&mut self) {
            self.not_logged_in += 1;
        }
    }

    // Ruby: test "when not authenticated only notifies not logged in"
    #[test]
    fn when_not_authenticated_only_notifies_not_logged_in() {
        let gateway = FakeRevocationGateway {
            deleted_user_ids: Mutex::new(vec![]),
        };
        let mut port = RecordingPort::default();
        let mut interactor = AuthUserLogoutInteractor::new(&mut port, &gateway);

        interactor.call(false, 1);

        assert_eq!(port.not_logged_in, 1);
        assert_eq!(port.success, 0);
        assert!(gateway.deleted_user_ids.lock().unwrap().is_empty());
    }

    // Ruby: test "when authenticated revokes then success"
    #[test]
    fn when_authenticated_revokes_then_success() {
        let gateway = FakeRevocationGateway {
            deleted_user_ids: Mutex::new(vec![]),
        };
        let mut port = RecordingPort::default();
        let mut interactor = AuthUserLogoutInteractor::new(&mut port, &gateway);

        interactor.call(true, 42);

        assert_eq!(port.success, 1);
        assert_eq!(port.not_logged_in, 0);
        assert_eq!(*gateway.deleted_user_ids.lock().unwrap(), vec![42]);
    }
