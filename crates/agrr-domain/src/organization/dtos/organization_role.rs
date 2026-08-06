//! Organization membership roles (ADR-002 phase 1).

/// `owner` / `admin` / `member` — see ADR-002 and organization-data-model.md.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum OrganizationRole {
    Owner,
    Admin,
    Member,
}

impl OrganizationRole {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "owner" => Some(Self::Owner),
            "admin" => Some(Self::Admin),
            "member" => Some(Self::Member),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Owner => "owner",
            Self::Admin => "admin",
            Self::Member => "member",
        }
    }
}

#[cfg(test)]
mod dtos_organization_role_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/dtos_organization_role_test.rs"
    ));
}
