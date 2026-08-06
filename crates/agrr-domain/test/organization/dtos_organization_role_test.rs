// Tests for `dtos/organization_role.rs`

use crate::organization::dtos::OrganizationRole;

#[test]
fn parses_known_roles() {
    assert_eq!(OrganizationRole::parse("owner"), Some(OrganizationRole::Owner));
    assert_eq!(OrganizationRole::parse("admin"), Some(OrganizationRole::Admin));
    assert_eq!(OrganizationRole::parse("member"), Some(OrganizationRole::Member));
}

#[test]
fn rejects_unknown_role() {
    assert_eq!(OrganizationRole::parse("guest"), None);
}

#[test]
fn round_trips_as_str() {
    for role in [
        OrganizationRole::Owner,
        OrganizationRole::Admin,
        OrganizationRole::Member,
    ] {
        assert_eq!(OrganizationRole::parse(role.as_str()), Some(role));
    }
}
