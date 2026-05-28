//! Ruby: `Domain::Field::Interactors::FieldDestroyInteractor`

use crate::field::dtos::FieldDestroyOutput;
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{DestroyFailure, FieldDestroyOutputPort};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordNotFoundError};
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

/// Ruby: `Domain::Field::Interactors::FieldDestroyInteractor`
pub struct FieldDestroyInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> FieldDestroyInteractor<'a, G, O, L, T>
where
    G: FieldGateway,
    O: FieldDestroyOutputPort,
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
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(&mut self, field_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();
        match self.gateway.field_with_farm(field_id) {
            Ok(with_farm) => {
                if let Err(policy) = assert_owned(&user, &with_farm.farm) {
                    self.output_port.on_failure(DestroyFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &with_farm.farm)
                {
                    self.output_port.on_failure(DestroyFailure::Policy(policy));
                    return Ok(());
                }
                match self.gateway.delete(field_id) {
                    Ok(undo) => {
                        self.output_port
                            .on_success(FieldDestroyOutput::new(undo));
                        Ok(())
                    }
                    Err(err) => Self::handle_err(&mut self.output_port, &*self.translator, &opts, err),
                }
            }
            Err(err) => Self::handle_err(&mut self.output_port, &*self.translator, &opts, err),
        }
    }

    fn handle_err(
        output_port: &mut O,
        translator: &dyn TranslatorPort,
        opts: &TranslateOptions,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            output_port.on_failure(DestroyFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            output_port.on_failure(DestroyFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let message = translator.t("fields.flash.cannot_delete_in_use", opts);
            output_port.on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::entities::FieldEntity;
    use crate::field::results::{FarmRecord, FieldWithFarm};
    use crate::shared::ports::translator_port::TranslateOptions;
    use crate::shared::user::User;
    use serde_json::json;

    struct KeyTranslator;
    impl TranslatorPort for KeyTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(
            &self,
            _: time::Date,
            _: Option<&str>,
            _: &TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    enum MockBehavior {
        OkDelete,
        OtherOwner,
        NotFound,
    }

    struct StubGateway {
        behavior: MockBehavior,
    }

    impl FieldGateway for StubGateway {
        fn get_total_area_by_farm_id(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0.0)
        }

        fn farm_fields_list(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FarmFieldsList, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }

        fn field_with_farm(
            &self,
            _: i64,
        ) -> Result<FieldWithFarm, Box<dyn std::error::Error + Send + Sync>> {
            match self.behavior {
                MockBehavior::OkDelete => Ok(FieldWithFarm::new(
                    FarmRecord {
                        id: 1,
                        name: "F".into(),
                        user_id: Some(20),
                        is_reference: false,
                        latitude: None,
                        longitude: None,
                        region: None,
                        created_at: None,
                        updated_at: None,
                    },
                    FieldEntity {
                        id: 7,
                        farm_id: 1,
                        user_id: Some(20),
                        name: "N".into(),
                        description: None,
                        created_at: None,
                        updated_at: None,
                        area: None,
                        daily_fixed_cost: None,
                        region: None,
                    },
                )),
                MockBehavior::OtherOwner => Ok(FieldWithFarm::new(
                    FarmRecord {
                        id: 1,
                        name: "F".into(),
                        user_id: Some(99),
                        is_reference: false,
                        latitude: None,
                        longitude: None,
                        region: None,
                        created_at: None,
                        updated_at: None,
                    },
                    FieldEntity {
                        id: 7,
                        farm_id: 1,
                        user_id: Some(99),
                        name: "N".into(),
                        description: None,
                        created_at: None,
                        updated_at: None,
                        area: None,
                        daily_fixed_cost: None,
                        region: None,
                    },
                )),
                MockBehavior::NotFound => Err(Box::new(RecordNotFoundError)),
            }
        }

        fn create(
            &self,
            _: &crate::field::dtos::FieldCreateInput,
            _: i64,
            _: &crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
                crate::shared::policies::farm_policy::FarmRecordAccessPolicy,
            >,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: &crate::field::dtos::FieldUpdateInput,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(json!({
                "undo_token": "tok",
                "toast_message": "m",
                "undo_path": "/u"
            }))
        }
    }

    struct SpyOutput {
        success: Option<FieldDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl FieldDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FieldDestroyOutput) {
            self.success = Some(dto);
        }

        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "call passes FieldDestroyOutput to output port on success"
    #[test]
    fn call_passes_field_destroy_output_on_success() {
        let gateway = StubGateway {
            behavior: MockBehavior::OkDelete,
        };
        let translator = KeyTranslator;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(20, false));
        let mut interactor =
            FieldDestroyInteractor::new(&mut output, 20, &gateway, &translator, &lookup);
        interactor.call(7).unwrap();
        let dto = output.success.unwrap();
        assert_eq!(dto.undo["undo_token"], "tok");
    }

    // Ruby: test "call forwards RecordNotFound to on_failure as Error"
    #[test]
    fn call_forwards_record_not_found() {
        let gateway = StubGateway {
            behavior: MockBehavior::NotFound,
        };
        let translator = KeyTranslator;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(20, false));
        let mut interactor =
            FieldDestroyInteractor::new(&mut output, 20, &gateway, &translator, &lookup);
        interactor.call(7).unwrap();
        assert!(matches!(output.failure, Some(DestroyFailure::Error(_))));
    }

    // Ruby: test "call forwards policy permission denied to on_failure as exception"
    #[test]
    fn call_forwards_policy_permission_denied() {
        let gateway = StubGateway {
            behavior: MockBehavior::OtherOwner,
        };
        let translator = KeyTranslator;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(20, false));
        let mut interactor =
            FieldDestroyInteractor::new(&mut output, 20, &gateway, &translator, &lookup);
        interactor.call(7).unwrap();
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
}
