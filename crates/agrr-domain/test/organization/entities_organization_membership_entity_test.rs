// Placeholder — membership entity has no behavior yet beyond field storage.

use crate::organization::dtos::OrganizationRole;
use crate::organization::entities::OrganizationMembershipEntity;

#[test]
fn stores_role() {
    let m = OrganizationMembershipEntity {
        id: 1,
        organization_id: 2,
        user_id: 3,
        role: OrganizationRole::Admin,
        created_at: String::new(),
        updated_at: String::new(),
    };
    assert_eq!(m.role, OrganizationRole::Admin);
}
