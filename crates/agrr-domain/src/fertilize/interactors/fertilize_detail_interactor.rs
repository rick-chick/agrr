//! Ruby: `Domain::Fertilize::Interactors::FertilizeDetailInteractor`

use crate::fertilize::dtos::FertilizeDetailOutput;
use crate::fertilize::gateways::FertilizeGateway;
use crate::fertilize::ports::{DetailFailure, FertilizeDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FertilizeDetailInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeDetailInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeDetailOutputPort,
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

        let entity = match self.gateway.find_by_id(fertilize_id) {
            Ok(e) => e,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("fertilizes.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &entity)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port
            .on_success(FertilizeDetailOutput::new(&entity));
        Ok(())
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

    struct DetailGateway {
        entity: FertilizeEntity,
    }

    impl FertilizeGateway for DetailGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
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
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
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
        detail: Option<FertilizeDetailOutput>,
        failure: Option<DetailFailure>,
    }

    impl FertilizeDetailOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FertilizeDetailOutput) {
            self.detail = Some(dto);
        }
        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "call passes fertilize detail dto to output port"
    #[test]
    fn passes_detail_dto_to_output_port() {
        let entity = FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(1),
            user_id: Some(42),
            name: "Test".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let gateway = DetailGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            detail: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(42, false));
        let mut interactor = FertilizeDetailInteractor::new(
            &mut output,
            42,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(99).expect("handled");
        assert_eq!(
            output.detail.as_ref().map(|d| d.display_dto.id),
            Some(Some(1))
        );
    }

    // Ruby: test "call maps RecordNotFound to translated not_found flash"
    #[test]
    fn maps_record_not_found_to_translated_message() {
        struct NotFoundGateway;
        impl FertilizeGateway for NotFoundGateway {
            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
                Err(Box::new(RecordNotFoundError))
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
            ) -> Result<
                crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn find_by_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
        }

        struct Translated;
        impl TranslatorPort for Translated {
            fn translate(&self, key: &str, _: &TranslateOptions) -> String {
                if key == "fertilizes.flash.not_found" {
                    "指定された肥料が見つかりません。".into()
                } else {
                    key.into()
                }
            }
            fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
                String::new()
            }
        }

        let mut output = SpyOutput {
            detail: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(42, false));
        let mut interactor = FertilizeDetailInteractor::new(
            &mut output,
            42,
            &NotFoundGateway,
            &Translated,
            &lookup,
        );
        interactor.call(1).expect("handled");
        match output.failure {
            Some(DetailFailure::Error(e)) => {
                assert_eq!(e.message, "指定された肥料が見つかりません。");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
}
