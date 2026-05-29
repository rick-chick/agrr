//! Ruby: `Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor`

use crate::cultivation_plan::dtos::CultivationPlanDestroyOutput;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::policies::private_cultivation_plan_access_policy;
use crate::cultivation_plan::ports::CultivationPlanDestroyOutputPort;
use crate::deletion_undo::exceptions::DeletionUndoError;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct CultivationPlanDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CultivationPlanDestroyInteractor<'a, G, O, U, T>
where
    G: CultivationPlanGateway,
    O: CultivationPlanDestroyOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        let plan = match self.gateway.find_by_id(plan_id) {
            Ok(plan) => plan,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let Err(PolicyPermissionDenied) =
            private_cultivation_plan_access_policy::assert_private_owned(&user, &plan)
        {
            self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
            return Ok(());
        }

        let display_name = self
            .gateway
            .private_owned_plan_display_name(&user, plan_id)?;
        let toast_message = self
            .translator
            .t_with_name("plans.undo.toast", &display_name, &opts);

        match self.gateway.delete(plan_id, &user, &toast_message) {
            Ok(undo) => {
                self.output_port
                    .on_success(CultivationPlanDestroyOutput::new(undo));
                Ok(())
            }
            Err(err) if err.downcast_ref::<AssociationInUseError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.delete_failed", &opts));
                Ok(())
            }
            Err(err) if err.downcast_ref::<DeletionUndoError>().is_some() => {
                let e = err.downcast_ref::<DeletionUndoError>().unwrap();
                let message = self.translator.t_with_message(
                    "plans.errors.delete_error",
                    &e.0,
                    &opts,
                );
                self.handle_failure(message);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.handle_failure(self.translator.t("plans.errors.not_found", &opts));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                let message = invalid
                    .detail_message()
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| invalid.to_string());
                self.handle_failure(message);
                Ok(())
            }
            Err(err) => Err(err),
        }
    }

    fn handle_failure(&mut self, message: String) {
        self.output_port.on_failure(Error::new(message));
    }
}

trait DestroyTranslatorExt {
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String;
    fn t_with_message(&self, key: &str, message: &str, opts: &TranslateOptions) -> String;
}

impl<T: TranslatorPort> DestroyTranslatorExt for T {
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("name".into(), name.to_string());
        self.t(key, &o)
    }

    fn t_with_message(&self, key: &str, message: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("message".into(), message.to_string());
        self.t(key, &o)
    }
}

#[cfg(test)]
mod interactors_cultivation_plan_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_cultivation_plan_destroy_interactor_test.rs"));
}
