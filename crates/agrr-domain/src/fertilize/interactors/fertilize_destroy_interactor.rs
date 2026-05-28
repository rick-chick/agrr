//! Ruby: `Domain::Fertilize::Interactors::FertilizeDestroyInteractor`

use crate::fertilize::dtos::FertilizeDestroyOutput;
use crate::fertilize::gateways::{FertilizeGateway, SoftDeleteWithUndoOutcome};
use crate::fertilize::ports::{DestroyFailure, FertilizeDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FertilizeDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeDestroyInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeDestroyOutputPort,
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
        fertilize_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = fertilize_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(fertilize_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("fertilizes.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
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

        match self
            .gateway
            .soft_delete_with_undo(&user, fertilize_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(FertilizeDestroyOutput::new(undo));
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
            output_port.on_failure(DestroyFailure::Error(Error::new("Record not found".to_string())));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "fertilizes.flash.cannot_delete_in_use".to_string(),
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct DestroyGateway {
        current: FertilizeEntity,
        undo: serde_json::Value,
    }

    impl FertilizeGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            Ok(SoftDeleteWithUndoOutcome::Success {
                undo: self.undo.clone(),
            })
        }

        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<FertilizeDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl FertilizeDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FertilizeDestroyOutput) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_success when delete is allowed"
    #[test]
    fn calls_on_success_when_delete_allowed() {
        let user_id = 10;
        let current = FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(7),
            user_id: Some(user_id),
            name: "F".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let undo = serde_json::json!({"id": 1});
        let gateway = DestroyGateway {
            current,
            undo: undo.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeDestroyInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(7).expect("handled");
        assert_eq!(output.success.as_ref().map(|d| d.undo.clone()), Some(undo));
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_when_permission_denied() {
        let user_id = 10;
        let current = FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(7),
            user_id: Some(99),
            name: "F".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let gateway = DestroyGateway {
            current,
            undo: serde_json::json!({}),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeDestroyInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(7).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
