use serde_json::Value;

/// HTTP status codes used by AI fertilize interactors.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpStatus {
    Ok,
    Created,
    BadRequest,
    Unauthorized,
    NotFound,
    UnprocessableEntity,
    ServiceUnavailable,
}

/// Ruby: `Domain::Shared::Dtos::HttpJsonEnvelope`
#[derive(Debug, Clone, PartialEq)]
pub struct HttpJsonEnvelope {
    pub status: HttpStatus,
    pub body: Value,
}

impl HttpJsonEnvelope {
    pub fn new(status: HttpStatus, body: Value) -> Self {
        Self { status, body }
    }
}
