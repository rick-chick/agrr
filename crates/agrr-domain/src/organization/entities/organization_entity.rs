//! Ruby: `Domain::Organization::Entities::OrganizationEntity`

/// Organization tenant root (B2B multi-tenancy).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationEntity {
    pub id: i64,
    pub name: String,
    pub slug: String,
    pub is_personal: bool,
    pub created_at: String,
    pub updated_at: String,
}

impl OrganizationEntity {
    pub fn deletable(&self) -> bool {
        !self.is_personal
    }
}

#[cfg(test)]
mod entities_organization_entity_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/entities_organization_entity_test.rs"
    ));
}
