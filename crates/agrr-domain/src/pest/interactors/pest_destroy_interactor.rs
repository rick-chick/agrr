//! Ruby: `Domain::Pest::Interactors::PestDestroyInteractor`

use crate::pest::dtos::PestDestroyOutput;
use crate::pest::gateways::{PestGateway, SoftDeleteWithUndoOutcome};
use crate::pest::policies::{blocked_reason, PestDestroyBlockedReason};
use crate::pest::ports::{DestroyFailure, PestDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct PestDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PestDestroyInteractor<'a, G, O, U, T>
where
    G: PestGateway,
    O: PestDestroyOutputPort,
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
        pest_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pest_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(pest_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(_) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            let message = self.translator.t("pests.flash.no_permission", &opts);
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        let usage = self.gateway.find_delete_usage(pest_id)?;
        if blocked_reason(&usage) == Some(PestDestroyBlockedReason::PesticidesInUse) {
            let message = self
                .translator
                .t("pests.flash.cannot_delete_in_use", &opts);
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self
            .gateway
            .soft_delete_with_undo(&user, pest_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(PestDestroyOutput::new(undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(DestroyFailure::Policy(PolicyPermissionDenied));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                match err.downcast::<RecordInvalidError>() {
                    Ok(record_invalid) => {
                        self.output_port.on_failure(DestroyFailure::Error(Error::new(
                            record_invalid.to_string(),
                        )));
                        Ok(())
                    }
                    Err(err) => Err(err),
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::dtos::PestDeleteUsage;
    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator {
        key: &'static str,
        message: &'static str,
    }

    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            if key == self.key {
                self.message.to_string()
            } else {
                key.to_string()
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    fn owned_pest(user_id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(7),
            user_id: Some(user_id),
            name: "p".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct DestroyGateway {
        current: PestEntity,
        usage: PestDeleteUsage,
        undo: serde_json::Value,
        block_soft_delete: bool,
    }

    impl PestGateway for DestroyGateway {

        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.usage)
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            if self.block_soft_delete {
                unimplemented!()
            }
            Ok(SoftDeleteWithUndoOutcome::Success {
                undo: self.undo.clone(),
            })
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }
}

