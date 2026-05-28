//! Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageInput`

/// Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateContactMessageInput {
    pub name: Option<String>,
    pub email: String,
    pub subject: Option<String>,
    pub message: String,
    pub source: Option<String>,
    pub recaptcha_token: Option<String>,
    pub remote_ip: Option<String>,
}

impl CreateContactMessageInput {
    pub fn new(
        name: Option<String>,
        email: impl Into<String>,
        subject: Option<String>,
        message: impl Into<String>,
        source: Option<String>,
        recaptcha_token: Option<String>,
        remote_ip: Option<String>,
    ) -> Self {
        Self {
            name,
            email: email.into(),
            subject,
            message: message.into(),
            source,
            recaptcha_token,
            remote_ip,
        }
    }
}
