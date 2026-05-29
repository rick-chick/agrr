// Tests for `interactors/masters_api_credentials_resolve_interactor.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::dtos::SessionPrincipal;
    use std::sync::Mutex;

    fn principal(authenticated: bool) -> SessionPrincipal {
        SessionPrincipal {
            id: 1,
            email: "u@example.com".into(),
            name: "User".into(),
            admin: false,
            anonymous: !authenticated,
        }
    }

    fn input_dto(api_key: Option<&str>, session_id: Option<&str>) -> MastersApiCredentialsResolveInput {
        MastersApiCredentialsResolveInput::new(
            api_key.map(str::to_string),
            session_id.map(str::to_string),
        )
    }

    struct FakeApiKeyGateway {
        principal: Option<SessionPrincipal>,
        calls: Mutex<Vec<String>>,
    }

    impl Default for FakeApiKeyGateway {
        fn default() -> Self {
            Self {
                principal: None,
                calls: Mutex::new(Vec::new()),
            }
        }
    }

    impl ApiKeyPrincipalGateway for FakeApiKeyGateway {
        fn principal_for_api_key(&self, api_key: &str) -> Option<SessionPrincipal> {
            self.calls.lock().unwrap().push(api_key.to_string());
            self.principal.clone()
        }
    }

    struct FakeSessionGateway {
        principal: SessionPrincipal,
        calls: Mutex<Vec<Option<String>>>,
    }

    impl Default for FakeSessionGateway {
        fn default() -> Self {
            Self {
                principal: principal(false),
                calls: Mutex::new(Vec::new()),
            }
        }
    }

    impl SessionCookiePrincipalGateway for FakeSessionGateway {
        fn principal_for_session_cookie(&self, session_id: Option<&str>) -> SessionPrincipal {
            self.calls
                .lock()
                .unwrap()
                .push(session_id.map(str::to_string));
            self.principal.clone()
        }
    }

    #[derive(Default)]
    struct FakeOutputPort {
        successes: Mutex<Vec<SessionPrincipal>>,
        invalid_api_key: Mutex<u32>,
        login_required: Mutex<u32>,
    }

    impl MastersApiCredentialsResolveOutputPort for FakeOutputPort {
        fn on_success(&mut self, principal: SessionPrincipal) {
            self.successes.lock().unwrap().push(principal);
        }

        fn on_invalid_api_key(&mut self) {
            *self.invalid_api_key.lock().unwrap() += 1;
        }

        fn on_login_required(&mut self) {
            *self.login_required.lock().unwrap() += 1;
        }
    }

    #[test]
    fn valid_api_key_resolves_via_api_key_gateway() {
        let api_gw = FakeApiKeyGateway {
            principal: Some(principal(true)),
            ..Default::default()
        };
        let session_gw = FakeSessionGateway::default();
        let mut port = FakeOutputPort::default();
        let mut interactor =
            MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);

        interactor.call(&input_dto(Some("key-1"), Some("sess-ignored")));

        assert_eq!(api_gw.calls.lock().unwrap().as_slice(), &["key-1".to_string()]);
        assert!(session_gw.calls.lock().unwrap().is_empty());
        assert_eq!(port.successes.lock().unwrap().len(), 1);
        assert_eq!(*port.invalid_api_key.lock().unwrap(), 0);
        assert_eq!(*port.login_required.lock().unwrap(), 0);
    }

    #[test]
    fn invalid_api_key_notifies_invalid_key() {
        let api_gw = FakeApiKeyGateway::default();
        let session_gw = FakeSessionGateway::default();
        let mut port = FakeOutputPort::default();
        let mut interactor =
            MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);

        interactor.call(&input_dto(Some("bad"), None));

        assert_eq!(api_gw.calls.lock().unwrap().as_slice(), &["bad".to_string()]);
        assert!(session_gw.calls.lock().unwrap().is_empty());
        assert!(port.successes.lock().unwrap().is_empty());
        assert_eq!(*port.invalid_api_key.lock().unwrap(), 1);
        assert_eq!(*port.login_required.lock().unwrap(), 0);
    }

    #[test]
    fn no_api_key_uses_session_gateway_when_authenticated() {
        let api_gw = FakeApiKeyGateway::default();
        let session_gw = FakeSessionGateway {
            principal: principal(true),
            calls: Mutex::new(Vec::new()),
        };
        let mut port = FakeOutputPort::default();
        let mut interactor =
            MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);

        interactor.call(&input_dto(None, Some("sess-1")));

        assert!(api_gw.calls.lock().unwrap().is_empty());
        assert_eq!(
            session_gw.calls.lock().unwrap().as_slice(),
            &[Some("sess-1".to_string())]
        );
        assert_eq!(port.successes.lock().unwrap().len(), 1);
        assert_eq!(*port.login_required.lock().unwrap(), 0);
    }

    #[test]
    fn no_api_key_and_anonymous_session_requires_login() {
        let api_gw = FakeApiKeyGateway::default();
        let session_gw = FakeSessionGateway {
            principal: principal(false),
            calls: Mutex::new(Vec::new()),
        };
        let mut port = FakeOutputPort::default();
        let mut interactor =
            MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);

        interactor.call(&input_dto(Some(""), None));

        assert!(api_gw.calls.lock().unwrap().is_empty());
        assert_eq!(session_gw.calls.lock().unwrap().as_slice(), &[None]);
        assert!(port.successes.lock().unwrap().is_empty());
        assert_eq!(*port.login_required.lock().unwrap(), 1);
    }

    #[test]
    fn whitespace_only_api_key_skips_api_key_gateway_and_uses_session() {
        let api_gw = FakeApiKeyGateway::default();
        let session_gw = FakeSessionGateway {
            principal: principal(false),
            calls: Mutex::new(Vec::new()),
        };
        let mut port = FakeOutputPort::default();
        let mut interactor =
            MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);

        interactor.call(&input_dto(Some("   "), Some("sess-1")));

        assert!(api_gw.calls.lock().unwrap().is_empty());
        assert_eq!(
            session_gw.calls.lock().unwrap().as_slice(),
            &[Some("sess-1".to_string())]
        );
        assert!(port.successes.lock().unwrap().is_empty());
        assert_eq!(*port.login_required.lock().unwrap(), 1);
    }
