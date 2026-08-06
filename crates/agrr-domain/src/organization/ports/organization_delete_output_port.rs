use crate::organization::dtos::OrganizationDeleteFailure;

pub trait OrganizationDeleteOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure: OrganizationDeleteFailure);
}
