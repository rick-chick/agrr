// Tests for `entities/organization_entity.rs`

use crate::organization::entities::OrganizationEntity;

fn sample_org(is_personal: bool) -> OrganizationEntity {
    OrganizationEntity {
        id: 1,
        name: "Acme Farm".into(),
        slug: "acme-farm".into(),
        is_personal,
        created_at: "2026-01-01T00:00:00Z".into(),
        updated_at: "2026-01-01T00:00:00Z".into(),
    }
}

#[test]
fn deletable_when_not_personal() {
    assert!(sample_org(false).deletable());
}

#[test]
fn not_deletable_when_personal() {
    assert!(!sample_org(true).deletable());
}
