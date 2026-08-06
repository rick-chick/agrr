use crate::organization::dtos::OrganizationListFailure;
use crate::organization::entities::OrganizationEntity;

pub trait OrganizationListOutputPort {
    fn on_success(&mut self, organizations: Vec<OrganizationEntity>);
    fn on_failure(&mut self, failure: OrganizationListFailure);
}
