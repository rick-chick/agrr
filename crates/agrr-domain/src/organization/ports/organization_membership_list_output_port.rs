use crate::organization::dtos::OrganizationMembershipListFailure;
use crate::organization::entities::OrganizationMembershipEntity;

pub trait OrganizationMembershipListOutputPort {
    fn on_success(&mut self, memberships: Vec<OrganizationMembershipEntity>);
    fn on_failure(&mut self, failure: OrganizationMembershipListFailure);
}
