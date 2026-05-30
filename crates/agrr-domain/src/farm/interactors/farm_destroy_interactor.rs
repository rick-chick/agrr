//! Ruby: `Domain::Farm::Interactors::FarmDestroyInteractor`

use crate::farm::dtos::FarmDestroyOutput;
use crate::farm::gateways::{FarmGateway, SoftDeleteWithUndoOutcome};
use crate::farm::policies::{FarmDestroyBlockedReason, FarmDestroyPolicy};
use crate::farm::ports::{DestroyFailure, FarmDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{
    AssociationInUseError, RecordInvalidError, RecordNotFoundError,
};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FarmDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FarmDestroyInteractor<'a, G, O, U, T>
where
    G: FarmGateway,
    O: FarmDestroyOutputPort,
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
        farm_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = farm_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let farm_entity = match self.gateway.find_by_id(farm_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("farms.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &farm_entity)
        {
            self.output_port.on_failure(DestroyFailure::Policy(policy));
            return Ok(());
        }

        let usage = self.gateway.find_delete_usage(farm_id)?;
        if matches!(
            FarmDestroyPolicy::blocked_reason(&usage),
            Some(FarmDestroyBlockedReason::FreeCropPlans)
        ) {
            let message = self.translator.t_with_count(
                "farms.flash.cannot_delete",
                usage.free_crop_plans_count,
                &opts,
            );
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        let toast_message = self.translator.t_with_name(
            "flash.farms.deleted",
            &farm_entity.name,
            &opts,
        );

        match self.gateway.soft_delete_with_undo(
            &user,
            farm_id,
            5000,
            &toast_message,
        ) {
            Ok(SoftDeleteWithUndoOutcome::Success { undo, farm_name }) => {
                self.output_port
                    .on_success(FarmDestroyOutput::new(undo, farm_name));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err, &opts),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
        opts: &TranslateOptions,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(DestroyFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "Record not found".to_string(),
            )));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "farms.flash.cannot_delete_in_use".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(DestroyFailure::Error(Error::new(record_invalid.to_string())));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

trait FarmDestroyTranslatorExt {
    fn t_with_count(&self, key: &str, count: i32, opts: &TranslateOptions) -> String;
    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String;
}

impl<T: TranslatorPort> FarmDestroyTranslatorExt for T {
    fn t_with_count(&self, key: &str, count: i32, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("count".into(), count.to_string());
        self.t(key, &o)
    }

    fn t_with_name(&self, key: &str, name: &str, opts: &TranslateOptions) -> String {
        let mut o = opts.clone();
        o.insert("name".into(), name.to_string());
        self.t(key, &o)
    }
}

#[cfg(test)]
mod interactors_farm_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_destroy_interactor_test.rs"));
}
