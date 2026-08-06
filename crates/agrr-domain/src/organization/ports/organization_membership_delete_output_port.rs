use crate::organization::dtos::OrganizationMembershipDeleteFailure;

pub trait OrganizationMembershipDeleteOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure: OrganizationMembershipDeleteFailure);
}
