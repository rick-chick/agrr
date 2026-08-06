use crate::organization::dtos::OrganizationFindFailure;
use crate::organization::entities::OrganizationEntity;

pub trait OrganizationFindOutputPort {
    fn on_success(&mut self, organization: OrganizationEntity);
    fn on_failure(&mut self, failure: OrganizationFindFailure);
}
