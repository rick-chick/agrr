//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor`

use crate::agricultural_task::dtos::AgriculturalTaskDetailOutput;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::agricultural_task::ports::{AgriculturalTaskDetailOutputPort, DetailFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::agricultural_task_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;

pub struct AgriculturalTaskDetailInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> AgriculturalTaskDetailInteractor<'a, G, O, L>
where
    G: AgriculturalTaskGateway,
    O: AgriculturalTaskDetailOutputPort,
    L: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a L) -> Self {
        Self { output_port, gateway, user_id, user_lookup }
    }

    pub fn call(&mut self, task_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = agricultural_task_policy::record_access_filter(user);
        match self.gateway.find_agricultural_task_show_detail(task_id) {
            Ok(detail) => {
                if let Err(policy) =
                    reference_record_authorization::assert_view_allowed(&access_filter, &detail.task)
                {
                    self.output_port.on_failure(DetailFailure::Policy(policy));
                    return Ok(());
                }
                self.output_port.on_success(AgriculturalTaskDetailOutput::from(detail));
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(DetailFailure::Policy(*policy));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port.on_failure(DetailFailure::Error(Error::new(
                        "Record not found".to_string(),
                    )));
                    return Ok(());
                }
                match err.downcast::<RecordInvalidError>() {
                    Ok(invalid) => {
                        self.output_port
                            .on_failure(DetailFailure::Error(Error::new(invalid.to_string())));
                        Ok(())
                    }
                    Err(err) => Err(err),
                }
            }
        }
    }
}

#[cfg(test)]
mod interactors_agricultural_task_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/interactors_agricultural_task_detail_interactor_test.rs"));
}
