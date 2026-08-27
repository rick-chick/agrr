//! `POST /api/v1/contact_messages` (anonymous).

use crate::contact_message_rate_limit::ContactMessageRateLimiterAdapter;
use crate::state::AppState;
use agrr_adapters_sqlite::ContactMessageSqliteGateway;
use agrr_domain::contact_messages::dtos::{
    CreateContactMessageFailure, CreateContactMessageInput, CreateContactMessageSuccess,
};
use agrr_domain::contact_messages::interactors::CreateContactMessageInteractor;
use agrr_domain::contact_messages::ports::CreateContactMessageOutputPort;
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::routing::{get, post};
use axum::{Json, Router};
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

pub fn remote_ip_from_headers(headers: &HeaderMap) -> Option<String> {
    if let Some(forwarded) = headers.get("x-forwarded-for").and_then(|v| v.to_str().ok()) {
        let ip = forwarded
            .split(',')
            .next()
            .map(str::trim)
            .filter(|ip| !ip.is_empty());
        if ip.is_some() {
            return ip.map(str::to_string);
        }
    }
    headers
        .get("x-real-ip")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|ip| !ip.is_empty())
        .map(str::to_string)
}

fn failure_response(failure: CreateContactMessageFailure) -> (StatusCode, Json<serde_json::Value>) {
    use agrr_domain::contact_messages::dtos::CreateContactMessageFailureKind;
    let (status, json) = match failure.kind {
        CreateContactMessageFailureKind::RateLimit => (
            StatusCode::TOO_MANY_REQUESTS,
            serde_json::json!({"error": "rate_limit"}),
        ),
        CreateContactMessageFailureKind::Recaptcha => (
            StatusCode::UNPROCESSABLE_ENTITY,
            serde_json::json!({"error": failure.message.unwrap_or_default()}),
        ),
        CreateContactMessageFailureKind::Validation => (
            StatusCode::UNPROCESSABLE_ENTITY,
            serde_json::json!({"errors": failure.errors.map(|e| e.full_messages()).unwrap_or_default()}),
        ),
    };
    (status, Json(json))
}

struct CreatePresenter {
    body: Option<(StatusCode, Json<serde_json::Value>)>,
}

impl CreateContactMessageOutputPort for CreatePresenter {
    fn on_success(&mut self, success: CreateContactMessageSuccess) {
        self.body = Some((
            StatusCode::CREATED,
            Json(serde_json::json!({
                "id": success.contact_message.id,
                "status": success.contact_message.status,
            })),
        ));
    }

    fn on_failure(&mut self, failure: CreateContactMessageFailure) {
        self.body = Some(failure_response(failure));
    }
}

async fn create(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ContactMessageBody>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let gateway = ContactMessageSqliteGateway::new(state.sqlite.clone());
    let remote_ip = remote_ip_from_headers(&headers).unwrap_or_else(|| "unknown".to_string());
    let recaptcha = state.recaptcha_verifier.as_ref();
    let rate_limit = ContactMessageRateLimiterAdapter::new(&state.contact_message_rate_limit, &remote_ip);
    let mut presenter = CreatePresenter { body: None };
    let input = CreateContactMessageInput::new(
        body.name,
        body.email,
        body.subject,
        body.message,
        body.source,
        body.recaptcha_token,
        Some(remote_ip),
    );
    let mut interactor = CreateContactMessageInteractor::new(
        &mut presenter,
        &gateway,
        recaptcha,
        &rate_limit,
    );
    interactor
        .call(input)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    match presenter.body {
        Some(response) => Ok(response),
        None => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderMap;

    #[test]
    fn failure_response_rate_limit_includes_json_body() {
        let (status, Json(json)) = failure_response(CreateContactMessageFailure::rate_limit());
        assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);
        assert_eq!(json["error"], "rate_limit");
    }

    #[test]
    fn remote_ip_prefers_x_forwarded_for_first_hop() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            "203.0.113.9, 198.51.100.2".parse().unwrap(),
        );
        assert_eq!(
            remote_ip_from_headers(&headers).as_deref(),
            Some("203.0.113.9")
        );
    }

    #[test]
    fn remote_ip_falls_back_to_x_real_ip() {
        let mut headers = HeaderMap::new();
        headers.insert("x-real-ip", "198.51.100.7".parse().unwrap());
        assert_eq!(
            remote_ip_from_headers(&headers).as_deref(),
            Some("198.51.100.7")
        );
    }
}
