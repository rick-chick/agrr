// Tests for `interactors/create_contact_message_interactor.rs` (Ruby parity under test/domain/contact_messages/).

    use crate::contact_messages::entities::{ContactMessage, ContactMessageAttrs};
    use crate::shared::validation::{ErrorsLike, ValidationErrors};

    struct NoopRecaptcha;

    impl RecaptchaVerifierPort for NoopRecaptcha {
        fn verify(&self, _token: Option<&str>, _remote_ip: Option<&str>) -> RecaptchaVerifyResult {
            RecaptchaVerifyResult::Ok
        }
    }

    struct NoopRateLimiter;

    impl ContactMessageRateLimiterPort for NoopRateLimiter {
        fn track(&self) -> RateLimitTrackResult {
            RateLimitTrackResult::Ok
        }
    }

    enum MockCreateBehavior {
        Return(ContactMessage),
        RaiseInvalid(ValidationErrors),
        RaiseOther(String),
        Unconfigured,
    }

    struct MockGateway {
        behavior: MockCreateBehavior,
    }

    impl ContactMessageGateway for MockGateway {
        fn find_by_id(&self, _id: i64) -> Option<ContactMessage> {
            None
        }

        fn create(
            &self,
            _input: &CreateContactMessageInput,
        ) -> Result<ContactMessage, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                MockCreateBehavior::Return(entity) => Ok(entity.clone()),
                MockCreateBehavior::RaiseInvalid(errors) => Err(Box::new(RecordInvalidError::new(
                    Some("Validation failed".into()),
                    Some(errors.clone()),
                ))),
                MockCreateBehavior::RaiseOther(msg) => {
                    Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, msg.clone())))
                }
                MockCreateBehavior::Unconfigured => {
                    panic!("gateway.create should not be called")
                }
            }
        }
    }

    impl MockGateway {
        fn returning(entity: ContactMessage) -> Self {
            Self {
                behavior: MockCreateBehavior::Return(entity),
            }
        }

        fn raising_invalid(errors: ValidationErrors) -> Self {
            Self {
                behavior: MockCreateBehavior::RaiseInvalid(errors),
            }
        }

        fn raising_other(msg: impl Into<String>) -> Self {
            Self {
                behavior: MockCreateBehavior::RaiseOther(msg.into()),
            }
        }

        fn unconfigured() -> Self {
            Self {
                behavior: MockCreateBehavior::Unconfigured,
            }
        }
    }

    struct SpyOutput {
        success: Option<CreateContactMessageSuccess>,
        failure: Option<CreateContactMessageFailure>,
    }

    impl CreateContactMessageOutputPort for SpyOutput {
        fn on_success(&mut self, success_dto: CreateContactMessageSuccess) {
            self.success = Some(success_dto);
        }

        fn on_failure(&mut self, failure_dto: CreateContactMessageFailure) {
            self.failure = Some(failure_dto);
        }
    }

    fn sample_input() -> CreateContactMessageInput {
        CreateContactMessageInput::new(
            Some("Taro".into()),
            "taro@example.com",
            Some("Hello".into()),
            "Hi",
            None,
            None,
            None,
        )
    }

    // Ruby: test "on success notifies output port"
    #[test]
    fn on_success_notifies_output_port() {
        let entity = ContactMessage::new(ContactMessageAttrs {
            id: Some(1),
            status: Some("queued".into()),
            ..Default::default()
        });
        let gateway = MockGateway::returning(entity.clone());
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };

        let recaptcha = NoopRecaptcha;
        let limiter = NoopRateLimiter;
        let mut interactor = CreateContactMessageInteractor::new(
            &mut output,
            &gateway,
            &recaptcha,
            &limiter,
        );

        interactor.call(sample_input()).expect("call succeeds");

        let received = output.success.expect("on_success called");
        assert_eq!(received.contact_message, entity);
    }

    // Ruby: test "calls on_failure when validation fails"
    #[test]
    fn calls_on_failure_when_validation_fails() {
        let record = ContactMessage::new(ContactMessageAttrs {
            email: Some("invalid".into()),
            message: Some(String::new()),
            ..Default::default()
        });
        let record_errors = record.validate();
        let gateway = MockGateway::raising_invalid(record_errors.clone());
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };

        let recaptcha = NoopRecaptcha;
        let limiter = NoopRateLimiter;
        let mut interactor = CreateContactMessageInteractor::new(
            &mut output,
            &gateway,
            &recaptcha,
            &limiter,
        );

        let input = CreateContactMessageInput::new(
            Some("Taro".into()),
            "invalid",
            Some("Hello".into()),
            "",
            None,
            None,
            None,
        );

        interactor.call(input).expect("call succeeds");

        let received = output.failure.expect("on_failure called");
        assert!(received.validation_kind());
        let errors = received.errors.expect("validation errors present");
        assert_eq!(
            errors.messages(),
            ValidationErrors::from_errors_like(ErrorsLike::ValidationErrors(&record_errors))
                .messages()
        );
    }

    // Ruby: test "propagates StandardError from gateway (no on_failure)"
    #[test]
    fn propagates_standard_error_from_gateway() {
        let gateway = MockGateway::raising_other("boom");
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };

        let recaptcha = NoopRecaptcha;
        let limiter = NoopRateLimiter;
        let mut interactor = CreateContactMessageInteractor::new(
            &mut output,
            &gateway,
            &recaptcha,
            &limiter,
        );

        let err = interactor
            .call(sample_input())
            .expect_err("error propagates");
        assert_eq!(err.to_string(), "boom");
        assert!(output.failure.is_none());
    }

    // Ruby: test "calls on_failure when rate limited"
    #[test]
    fn calls_on_failure_when_rate_limited() {
        struct RateLimited;

        impl ContactMessageRateLimiterPort for RateLimited {
            fn track(&self) -> RateLimitTrackResult {
                RateLimitTrackResult::RateLimited
            }
        }

        let gateway = MockGateway::unconfigured();
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };

        let recaptcha = NoopRecaptcha;
        let limiter = RateLimited;
        let mut interactor = CreateContactMessageInteractor::new(
            &mut output,
            &gateway,
            &recaptcha,
            &limiter,
        );

        interactor.call(sample_input()).expect("call succeeds");

        let received = output.failure.expect("on_failure called");
        assert!(received.rate_limit_kind());
    }

    // Ruby: test "calls on_failure when recaptcha fails"
    #[test]
    fn calls_on_failure_when_recaptcha_fails() {
        struct BadRecaptcha;

        impl RecaptchaVerifierPort for BadRecaptcha {
            fn verify(
                &self,
                _token: Option<&str>,
                _remote_ip: Option<&str>,
            ) -> RecaptchaVerifyResult {
                RecaptchaVerifyResult::Error("bad captcha".into())
            }
        }

        let gateway = MockGateway::unconfigured();
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };

        let recaptcha = BadRecaptcha;
        let limiter = NoopRateLimiter;
        let mut interactor = CreateContactMessageInteractor::new(
            &mut output,
            &gateway,
            &recaptcha,
            &limiter,
        );

        interactor.call(sample_input()).expect("call succeeds");

        let received = output.failure.expect("on_failure called");
        assert!(received.recaptcha_kind());
        assert_eq!(received.message.as_deref(), Some("bad captcha"));
    }
