use crate::organization::dtos::OrganizationMembershipCreateFailure;
use crate::organization::entities::OrganizationMembershipEntity;

pub trait OrganizationMembershipCreateOutputPort {
    fn on_success(&mut self, membership: OrganizationMembershipEntity);
    fn on_failure(&mut self, failure: OrganizationMembershipCreateFailure);
}
