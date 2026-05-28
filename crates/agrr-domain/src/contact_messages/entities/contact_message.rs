//! Ruby: `Domain::ContactMessages::Entities::ContactMessage`

use time::OffsetDateTime;

use crate::shared::validation::ValidationErrors;

/// Ruby: `Domain::ContactMessages::Entities::ContactMessage`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContactMessage {
    pub id: Option<i64>,
    pub name: Option<String>,
    pub email: Option<String>,
    pub subject: Option<String>,
    pub message: Option<String>,
    pub status: Option<String>,
    pub source: Option<String>,
    pub created_at: Option<OffsetDateTime>,
    pub sent_at: Option<OffsetDateTime>,
}

impl ContactMessage {
    pub fn new(attrs: ContactMessageAttrs) -> Self {
        Self {
            id: attrs.id,
            name: attrs.name,
            email: attrs.email,
            subject: attrs.subject,
            message: attrs.message,
            status: attrs.status,
            source: attrs.source,
            created_at: attrs.created_at,
            sent_at: attrs.sent_at,
        }
    }

    pub fn validate(&self) -> ValidationErrors {
        let mut errors = ValidationErrors::new();
        validate_email(self.email.as_deref(), &mut errors);
        validate_message(self.message.as_deref(), &mut errors);
        validate_optional_field_lengths(self, &mut errors);
        errors
    }

    pub fn valid(&self) -> bool {
        self.validate().is_empty()
    }

    pub fn sent(&self) -> bool {
        self.status.as_deref() == Some("sent")
    }

    pub fn failed(&self) -> bool {
        self.status.as_deref() == Some("failed")
    }

    pub fn queued(&self) -> bool {
        self.status.as_deref() == Some("queued")
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ContactMessageAttrs {
    pub id: Option<i64>,
    pub name: Option<String>,
    pub email: Option<String>,
    pub subject: Option<String>,
    pub message: Option<String>,
    pub status: Option<String>,
    pub source: Option<String>,
    pub created_at: Option<OffsetDateTime>,
    pub sent_at: Option<OffsetDateTime>,
}

fn str_blank(value: Option<&str>) -> bool {
    value.map(|s| s.trim().is_empty()).unwrap_or(true)
}

/// Approximates Ruby `URI::MailTo::EMAIL_REGEXP`.
fn valid_email_format(email: &str) -> bool {
    let Some((local, domain)) = email.split_once('@') else {
        return false;
    };
    if local.is_empty() || domain.is_empty() {
        return false;
    }
    if !domain.contains('.') {
        return false;
    }
    let domain_labels: Vec<&str> = domain.split('.').collect();
    if domain_labels.iter().any(|label| label.is_empty()) {
        return false;
    }
    local
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || ".!#$%&'*+/=?^_`{|}~-".contains(c))
        && domain
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '.')
}

fn validate_email(email: Option<&str>, errors: &mut ValidationErrors) {
    if str_blank(email) {
        errors.add("email", "can't be blank");
        return;
    }
    let email = email.unwrap();
    if email.len() > 255 {
        errors.add("email", "is too long (maximum is 255 characters)");
        return;
    }
    if !valid_email_format(email) {
        errors.add("email", "is invalid");
    }
}

fn validate_message(message: Option<&str>, errors: &mut ValidationErrors) {
    if str_blank(message) {
        errors.add("message", "can't be blank");
        return;
    }
    if message.unwrap().len() > 5000 {
        errors.add("message", "is too long (maximum is 5000 characters)");
    }
}

fn validate_optional_field_lengths(entity: &ContactMessage, errors: &mut ValidationErrors) {
    for (attr, value) in [
        ("name", entity.name.as_deref()),
        ("subject", entity.subject.as_deref()),
        ("source", entity.source.as_deref()),
    ] {
        if str_blank(value) {
            continue;
        }
        if value.unwrap().len() > 255 {
            errors.add(attr, "is too long (maximum is 255 characters)");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::macros::datetime;

    // Ruby: test "initializes with provided attributes and status helpers"
    #[test]
    fn initializes_with_provided_attributes_and_status_helpers() {
        let now = datetime!(2026-01-01 0:00 UTC);
        let entity = ContactMessage::new(ContactMessageAttrs {
            id: Some(1),
            name: Some("Taro".into()),
            email: Some("taro@example.com".into()),
            subject: Some("Hello".into()),
            message: Some("Hi there".into()),
            status: Some("sent".into()),
            created_at: Some(now),
            sent_at: Some(now),
            ..Default::default()
        });

        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name.as_deref(), Some("Taro"));
        assert_eq!(entity.email.as_deref(), Some("taro@example.com"));
        assert!(entity.sent());
        assert!(!entity.failed());
        assert!(!entity.queued());
    }

    // Ruby: test "requires email and message to be present"
    #[test]
    fn requires_email_and_message_to_be_present() {
        let entity = ContactMessage::new(ContactMessageAttrs {
            email: Some(String::new()),
            message: Some(String::new()),
            ..Default::default()
        });

        assert!(!entity.valid());
        assert!(!entity.validate().get("email").is_empty());
        assert!(!entity.validate().get("message").is_empty());
    }

    // Ruby: test "enforces length limits for optional fields"
    #[test]
    fn enforces_length_limits_for_optional_fields() {
        let mut entity = ContactMessage::new(ContactMessageAttrs {
            email: Some("a@b.com".into()),
            message: Some("ok".into()),
            ..Default::default()
        });
        entity.name = Some("n".repeat(300));
        entity.subject = Some("s".repeat(300));

        assert!(!entity.valid());
        assert!(!entity.validate().get("name").is_empty());
        assert!(!entity.validate().get("subject").is_empty());
    }
}
