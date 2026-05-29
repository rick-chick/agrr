// Tests for `ports/mod.rs` (Ruby parity under test/domain/shared/).

    use crate::shared::dtos::SessionPrincipal;
    use crate::shared::gateways::{
        ApiKeyPrincipalGateway, SessionCookiePrincipalGateway, UserLookupGateway,
    };
    use serde_json::json;
    use time::{Date, Month, OffsetDateTime};

    fn assert_send_sync<T: Send + Sync + ?Sized>() {}

    #[test]
    fn clock_port_is_object_safe() {
        assert_send_sync::<dyn ClockPort>();
        let _port: &dyn ClockPort = &NoopClock;
    }

    #[test]
    fn logger_port_is_object_safe() {
        let _port: &dyn LoggerPort = &NoopLogger;
    }

    #[test]
    fn sql_like_sanitize_port_is_object_safe() {
        let _port: &dyn SqlLikeSanitizePort = &NoopSqlLike;
    }

    #[test]
    fn translator_port_is_object_safe() {
        let _port: &dyn TranslatorPort = &NoopTranslator;
    }

    #[test]
    fn fetch_weather_enqueue_port_is_object_safe() {
        let _port: &dyn FetchWeatherDataEnqueuePort = &NoopWeatherEnqueue;
    }

    #[test]
    fn farm_refresh_broadcast_port_is_object_safe() {
        let _port: &dyn FarmRefreshBroadcastPort = &NoopFarmBroadcast;
    }

    #[test]
    fn cultivation_plan_phase_broadcast_port_is_object_safe() {
        let _port: &dyn CultivationPlanPhaseBroadcastPort = &NoopPlanBroadcast;
    }

    #[test]
    fn crop_agrr_requirement_builder_port_is_object_safe() {
        let source = NoopCropSource;
        let port = NoopCropBuilder;
        let _port: &dyn CropAgrrRequirementBuilderPort = &port;
        assert!(port.build_from(&source).is_object());
    }

    #[test]
    fn interaction_rule_agrr_format_builder_port_is_object_safe() {
        let source = NoopRuleSource;
        let port = NoopRuleBuilder;
        let _port: &dyn InteractionRuleAgrrFormatBuilderPort = &port;
        assert!(port.build_from(&source).is_object());
        assert!(port.build_array_from(&[&source]).is_empty());
    }

    #[test]
    fn api_key_principal_gateway_is_object_safe() {
        let _gw: &dyn ApiKeyPrincipalGateway = &NoopApiKeyGw;
    }

    #[test]
    fn session_cookie_principal_gateway_is_object_safe() {
        let _gw: &dyn SessionCookiePrincipalGateway = &NoopSessionGw;
    }

    #[test]
    fn user_lookup_gateway_is_object_safe() {
        let _gw: &dyn UserLookupGateway = &NoopUserLookup;
    }

    #[test]
    fn masters_api_credentials_resolve_output_port_is_object_safe() {
        let mut port = NoopMastersOutput;
        port.on_success(SessionPrincipal {
            id: 1,
            email: "u@example.com".into(),
            name: "User".into(),
            admin: false,
            anonymous: false,
        });
        port.on_invalid_api_key();
        port.on_login_required();
    }

    struct NoopClock;
    impl ClockPort for NoopClock {
        fn today(&self) -> Date {
            Date::from_calendar_date(2026, Month::January, 1).unwrap()
        }
        fn now(&self) -> OffsetDateTime {
            self.today()
                .with_hms(0, 0, 0)
                .unwrap()
                .assume_utc()
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct NoopSqlLike;
    impl SqlLikeSanitizePort for NoopSqlLike {
        fn sanitize_like(&self, term: &str) -> String {
            term.to_string()
        }
    }

    struct NoopTranslator;
    impl TranslatorPort for NoopTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct NoopWeatherEnqueue;
    impl FetchWeatherDataEnqueuePort for NoopWeatherEnqueue {
        fn enqueue_farm_weather_fetch(
            &self,
            _: i64,
            _: f64,
            _: f64,
            _: &[crate::shared::dtos::WeatherFetchDateBlock],
        ) {
        }
    }

    struct NoopFarmBroadcast;
    impl FarmRefreshBroadcastPort for NoopFarmBroadcast {
        fn broadcast_farm_weather_progress(&self, _: i64, _: &serde_json::Value) {}
    }

    struct NoopPlanBroadcast;
    impl CultivationPlanPhaseBroadcastPort for NoopPlanBroadcast {
        fn broadcast_phase_update(&self, _: i64, _: &str, _: &serde_json::Value) {}
    }

    struct NoopCropSource;
    impl CropAgrrRequirementSource for NoopCropSource {}

    struct NoopCropBuilder;
    impl CropAgrrRequirementBuilderPort for NoopCropBuilder {
        fn build_from(&self, _: &dyn CropAgrrRequirementSource) -> serde_json::Value {
            json!({})
        }
    }

    struct NoopRuleSource;
    impl InteractionRuleAgrrFormatSource for NoopRuleSource {}

    struct NoopRuleBuilder;
    impl InteractionRuleAgrrFormatBuilderPort for NoopRuleBuilder {
        fn build_from(&self, _: &dyn InteractionRuleAgrrFormatSource) -> serde_json::Value {
            json!({})
        }
        fn build_array_from(
            &self,
            _: &[&dyn InteractionRuleAgrrFormatSource],
        ) -> Vec<serde_json::Value> {
            vec![]
        }
    }

    struct NoopApiKeyGw;
    impl ApiKeyPrincipalGateway for NoopApiKeyGw {
        fn principal_for_api_key(&self, _: &str) -> Option<SessionPrincipal> {
            None
        }
    }

    struct NoopSessionGw;
    impl SessionCookiePrincipalGateway for NoopSessionGw {
        fn principal_for_session_cookie(&self, _: Option<&str>) -> SessionPrincipal {
            SessionPrincipal {
                id: 0,
                email: String::new(),
                name: String::new(),
                admin: false,
                anonymous: true,
            }
        }
    }

    struct NoopUserLookup;
    impl UserLookupGateway for NoopUserLookup {
        fn find(&self, user_id: i64) -> crate::shared::user::User {
            crate::shared::user::User::new(user_id, false)
        }
    }

    struct NoopMastersOutput;
    impl MastersApiCredentialsResolveOutputPort for NoopMastersOutput {
        fn on_success(&mut self, _: SessionPrincipal) {}
        fn on_invalid_api_key(&mut self) {}
        fn on_login_required(&mut self) {}
    }
