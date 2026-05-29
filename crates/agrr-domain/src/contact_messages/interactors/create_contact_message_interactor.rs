//! Ruby: `Domain::ContactMessages::Interactors::CreateContactMessageInteractor`

use crate::contact_messages::dtos::{
    CreateContactMessageFailure, CreateContactMessageInput, CreateContactMessageSuccess,
};
use crate::contact_messages::gateways::ContactMessageGateway;
use crate::contact_messages::ports::{
    ContactMessageRateLimiterPort, CreateContactMessageOutputPort, RateLimitTrackResult,
    RecaptchaVerifierPort, RecaptchaVerifyResult,
};
use crate::shared::exceptions::RecordInvalidError;

/// Ruby: `Domain::ContactMessages::Interactors::CreateContactMessageInteractor`
pub struct CreateContactMessageInteractor<'a, G, O, R, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    recaptcha_verifier: &'a R,
    rate_limiter: &'a L,
}

impl<'a, G, O, R, L> CreateContactMessageInteractor<'a, G, O, R, L>
where
    G: ContactMessageGateway,
    O: CreateContactMessageOutputPort,
    R: RecaptchaVerifierPort,
    L: ContactMessageRateLimiterPort,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        recaptcha_verifier: &'a R,
        rate_limiter: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            recaptcha_verifier,
            rate_limiter,
        }
    }

    /// Ruby: `#call(input)` — only `RecordInvalid` is mapped to `on_failure`; other errors propagate.
    pub fn call(
        &mut self,
        input: CreateContactMessageInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.rate_limiter.track() == RateLimitTrackResult::RateLimited {
            self.output_port
                .on_failure(CreateContactMessageFailure::rate_limit());
            return Ok(());
        }

        match self.recaptcha_verifier.verify(
            input.recaptcha_token.as_deref(),
            input.remote_ip.as_deref(),
        ) {
            RecaptchaVerifyResult::Ok => {}
            RecaptchaVerifyResult::Error(msg) => {
                self.output_port
                    .on_failure(CreateContactMessageFailure::recaptcha(msg));
                return Ok(());
            }
        }

        match self.gateway.create(&input) {
            Ok(entity) => {
                self.output_port
                    .on_success(CreateContactMessageSuccess::new(entity));
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    let errors = record_invalid.errors.unwrap_or_default();
                    self.output_port
                        .on_failure(CreateContactMessageFailure::validation(errors));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_create_contact_message_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/contact_messages/interactors_create_contact_message_interactor_test.rs"));
}
