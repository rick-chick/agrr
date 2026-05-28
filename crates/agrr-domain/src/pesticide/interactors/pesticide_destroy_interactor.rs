//! Ruby: `Domain::Pesticide::Interactors::PesticideDestroyInteractor`

use crate::pesticide::dtos::PesticideDestroyOutput;
use crate::pesticide::gateways::{PesticideGateway, SoftDeleteWithUndoOutcome};
use crate::pesticide::ports::{DestroyFailure, PesticideDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct PesticideDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PesticideDestroyInteractor<'a, G, O, U, T>
where
    G: PesticideGateway,
    O: PesticideDestroyOutputPort,
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
        pesticide_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pesticide_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(pesticide_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pesticides.flash.not_found", &opts);
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
            .soft_delete_with_undo(&user, pesticide_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(PesticideDestroyOutput::new(undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(
                &mut self.output_port,
                err,
                self.translator,
                &opts,
            ),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
        translator: &T,
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
            let message = translator.t("pesticides.flash.cannot_delete_in_use", opts);
            output_port.on_failure(DestroyFailure::Error(Error::new(message)));
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
    use crate::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            String::new()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct DestroyGateway {
        current: PesticideEntity,
    }

    impl PesticideGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_pesticide_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::pesticide::gateways::PesticideShowDetailGatewayDto,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!("should not be called when edit denied")
        }

        fn list_by_crop_id_for_filter(
            &self,
            _: i64,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        failure: Option<DestroyFailure>,
    }

    impl PesticideDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, _: PesticideDestroyOutput) {}
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let current = PesticideEntity::new(PesticideEntityAttrs {
            id: 7,
            user_id: Some(99),
            name: "P".into(),
            active_ingredient: None,
            description: None,
            crop_id: None,
            pest_id: None,
            region: None,
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid");
        let gateway = DestroyGateway { current };
        let mut output = SpyOutput { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideDestroyInteractor::new(
            &mut output,
            10,
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
