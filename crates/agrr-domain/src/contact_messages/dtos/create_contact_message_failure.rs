//! Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageFailure`

use crate::shared::validation::ValidationErrors;

/// Ruby: `CreateContactMessageFailure::KIND_*`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CreateContactMessageFailureKind {
    Validation,
    Captcha,
    RateLimit,
    Unavailable,
}

/// Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateContactMessageFailure {
    pub kind: CreateContactMessageFailureKind,
    pub errors: Option<ValidationErrors>,
    pub message: Option<String>,
}

impl CreateContactMessageFailure {
    pub fn validation(errors: ValidationErrors) -> Self {
        Self {
            kind: CreateContactMessageFailureKind::Validation,
            errors: Some(errors),
            message: None,
        }
    }

    pub fn captcha(message: impl Into<String>) -> Self {
        Self {
            kind: CreateContactMessageFailureKind::Captcha,
            errors: None,
            message: Some(message.into()),
        }
    }

    pub fn rate_limit() -> Self {
        Self {
            kind: CreateContactMessageFailureKind::RateLimit,
            errors: None,
            message: Some("Too many requests".into()),
        }
    }

    pub fn unavailable(message: impl Into<String>) -> Self {
        Self {
            kind: CreateContactMessageFailureKind::Unavailable,
            errors: None,
            message: Some(message.into()),
        }
    }

    pub fn validation_kind(&self) -> bool {
        self.kind == CreateContactMessageFailureKind::Validation
    }

    pub fn captcha_kind(&self) -> bool {
        self.kind == CreateContactMessageFailureKind::Captcha
    }

    pub fn rate_limit_kind(&self) -> bool {
        self.kind == CreateContactMessageFailureKind::RateLimit
    }

    pub fn unavailable_kind(&self) -> bool {
        self.kind == CreateContactMessageFailureKind::Unavailable
    }
}
