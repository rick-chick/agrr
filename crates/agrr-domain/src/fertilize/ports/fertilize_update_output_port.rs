use crate::fertilize::dtos::FertilizeUpdateFailure;
use crate::fertilize::entities::FertilizeEntity;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FertilizeUpdateOutputPort {
    fn on_success(&mut self, entity: FertilizeEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    Fertilize(FertilizeUpdateFailure),
}
