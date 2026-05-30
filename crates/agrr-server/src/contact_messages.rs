//! `POST /api/v1/contact_messages` (anonymous).

use crate::state::AppState;
use agrr_adapters_sqlite::ContactMessageSqliteGateway;
use agrr_domain::contact_messages::dtos::{
    CreateContactMessageFailure, CreateContactMessageInput, CreateContactMessageSuccess,
};
use agrr_domain::contact_messages::interactors::CreateContactMessageInteractor;
use agrr_domain::contact_messages::ports::{
    ContactMessageRateLimiterPort, CreateContactMessageOutputPort, RateLimitTrackResult,
    RecaptchaVerifierPort, RecaptchaVerifyResult,
};
use axum::{extract::State, http::StatusCode, routing::post, Json, Router};
use serde::Deserialize;

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/contact_messages",
        post(create).get(index_contact_messages),
    )
}

/// Rails routes `index` but has no controller action; empty list keeps parity without exposing data.
async fn index_contact_messages() -> Json<Vec<serde_json::Value>> {
    Json(vec![])
}

#[derive(Debug, Deserialize)]
struct ContactMessageBody {
    name: Option<String>,
    email: String,
    subject: Option<String>,
    message: String,
    source: Option<String>,
    recaptcha_token: Option<String>,
}

struct AllowAllRecaptcha;
impl RecaptchaVerifierPort for AllowAllRecaptcha {
    fn verify(&self, _token: Option<&str>, _remote_ip: Option<&str>) -> RecaptchaVerifyResult {
        RecaptchaVerifyResult::Ok
    }
}

struct AllowAllRateLimit;
impl ContactMessageRateLimiterPort for AllowAllRateLimit {
    fn track(&self) -> RateLimitTrackResult {
        RateLimitTrackResult::Ok
    }
}

struct CreatePresenter {
    body: Option<Result<(StatusCode, Json<serde_json::Value>), StatusCode>>,
}

impl CreateContactMessageOutputPort for CreatePresenter {
    fn on_success(&mut self, success: CreateContactMessageSuccess) {
        self.body = Some(Ok((
            StatusCode::CREATED,
            Json(serde_json::json!({
                "id": success.contact_message.id,
                "status": success.contact_message.status,
            })),
        )));
    }

    fn on_failure(&mut self, failure: CreateContactMessageFailure) {
        use agrr_domain::contact_messages::dtos::CreateContactMessageFailureKind;
        let (status, _json) = match failure.kind {
            CreateContactMessageFailureKind::RateLimit => {
                (StatusCode::TOO_MANY_REQUESTS, serde_json::json!({"error": "rate_limit"}))
            }
            CreateContactMessageFailureKind::Recaptcha => (
                StatusCode::UNPROCESSABLE_ENTITY,
                serde_json::json!({"error": failure.message.unwrap_or_default()}),
            ),
            CreateContactMessageFailureKind::Validation => (
                StatusCode::UNPROCESSABLE_ENTITY,
                serde_json::json!({"errors": failure.errors.map(|e| e.full_messages()).unwrap_or_default()}),
            ),
        };
        self.body = Some(Err(status));
    }
}

async fn create(
    State(state): State<AppState>,
    Json(body): Json<ContactMessageBody>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let gateway = ContactMessageSqliteGateway::new(state.sqlite.clone());
    let recaptcha = AllowAllRecaptcha;
    let rate_limit = AllowAllRateLimit;
    let mut presenter = CreatePresenter { body: None };
    let input = CreateContactMessageInput::new(
        body.name,
        body.email,
        body.subject,
        body.message,
        body.source,
        body.recaptcha_token,
        None,
    );
    let mut interactor = CreateContactMessageInteractor::new(
        &mut presenter,
        &gateway,
        &recaptcha,
        &rate_limit,
    );
    interactor.call(input).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    match presenter.body {
        Some(Ok(ok)) => Ok(ok),
        Some(Err(status)) => Err(status),
        None => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}
