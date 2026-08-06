//! Personal organization naming and slug conventions (ADR-002 / organization-data-model.md).

/// Slug for a user's 1:1 personal organization.
pub fn personal_organization_slug(user_id: i64) -> String {
    format!("user-{user_id}")
}

/// Display name: email when present, otherwise `"Personal"`.
pub fn personal_organization_name(email: &str) -> String {
    let trimmed = email.trim();
    if trimmed.is_empty() {
        "Personal".into()
    } else {
        trimmed.to_lowercase()
    }
}

#[cfg(test)]
mod personal_organization_policy_test {
    use super::*;

    #[test]
    fn slug_is_deterministic_per_user() {
        assert_eq!("user-42", personal_organization_slug(42));
    }

    #[test]
    fn name_uses_email_or_personal_fallback() {
        assert_eq!("a@example.com", personal_organization_name("A@Example.com"));
        assert_eq!("Personal", personal_organization_name(""));
        assert_eq!("Personal", personal_organization_name("   "));
    }
}
