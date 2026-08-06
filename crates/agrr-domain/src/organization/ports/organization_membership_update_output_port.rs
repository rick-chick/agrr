use crate::organization::dtos::OrganizationMembershipUpdateFailure;
use crate::organization::entities::OrganizationMembershipEntity;

pub trait OrganizationMembershipUpdateOutputPort {
    fn on_success(&mut self, membership: OrganizationMembershipEntity);
    fn on_failure(&mut self, failure: OrganizationMembershipUpdateFailure);
}
