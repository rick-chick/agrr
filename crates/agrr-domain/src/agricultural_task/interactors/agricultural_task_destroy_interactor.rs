//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor`

use crate::agricultural_task::dtos::AgriculturalTaskDestroyOutput;
use crate::agricultural_task::gateways::{AgriculturalTaskGateway, SoftDeleteUndoResult};
use crate::agricultural_task::ports::{AgriculturalTaskDestroyOutputPort, DestroyFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::agricultural_task_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct AgriculturalTaskDestroyInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> AgriculturalTaskDestroyInteractor<'a, G, O, L, T>
where
    G: AgriculturalTaskGateway,
    O: AgriculturalTaskDestroyOutputPort,
    L: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a L,
    ) -> Self {
        Self { output_port, gateway, user_id, translator, user_lookup }
    }

    pub fn call(&mut self, task_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = agricultural_task_policy::record_access_filter(user);
        let current = match self.gateway.find_by_id(task_id) {
            Ok(c) => c,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t(
                        "agricultural_tasks.flash.not_found",
                        &TranslateOptions::default(),
                    );
                    self.output_port.on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };
        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(DestroyFailure::Policy(policy));
            return Ok(());
        }
        let mut toast_opts = TranslateOptions::new();
        toast_opts.insert("name".into(), current.name.clone());
        let toast = self
            .translator
            .t("agricultural_tasks.undo.toast", &toast_opts);
        match self.gateway.soft_delete_with_undo(&user, task_id, 5000, &toast)? {
            SoftDeleteUndoResult::Success { undo } => {
                self.output_port
                    .on_success(AgriculturalTaskDestroyOutput::new(undo));
                Ok(())
            }
            SoftDeleteUndoResult::Failure { error } => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_agricultural_task_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/interactors_agricultural_task_destroy_interactor_test.rs"));
}
