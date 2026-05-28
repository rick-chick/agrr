use crate::farm::entities::FarmEntity;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

#[derive(Debug, Clone, PartialEq)]
pub struct FarmListSuccess {
    pub farms: Vec<FarmEntity>,
    pub reference_farms: Vec<FarmEntity>,
}

pub trait FarmListOutputPort {
    fn on_success(&mut self, result: FarmListSuccess);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
