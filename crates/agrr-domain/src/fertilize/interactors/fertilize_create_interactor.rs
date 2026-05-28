//! Ruby: `Domain::Fertilize::Interactors::FertilizeCreateInteractor`

use crate::fertilize::dtos::FertilizeCreateInput;
use crate::fertilize::entities::FertilizeEntity;
use crate::fertilize::gateways::FertilizeGateway;
use crate::fertilize::ports::{CreateFailure, FertilizeCreateOutputPort};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_assignment_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct FertilizeCreateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeCreateInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeCreateOutputPort,
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
        input: FertilizeCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();
        let is_reference = input.is_reference.unwrap_or(false);

        if !reference_assignment_allowed(&user, is_reference) {
            let message = self
                .translator
                .t("fertilizes.flash.reference_only_admin", &opts);
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        let attrs = fertilize_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from(input.name.as_str())),
                (
                    "n",
                    input
                        .n
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "p",
                    input
                        .p
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "k",
                    input
                        .k
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "description",
                    input
                        .description
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "package_size",
                    input
                        .package_size
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "region",
                    input
                        .region
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                ("is_reference", AttrValue::Bool(is_reference)),
            ]),
        );

        let effective_reference = attrs
            .get("is_reference")
            .map(crate::shared::type_converters::cast_boolean_attr)
            .unwrap_or(false);
        let effective_user_id = match attrs.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) | None => None,
            _ => None,
        };

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.fertilize.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.create_for_user(&user, attrs) {
            Ok(entity) => {
                self.output_port.on_success(entity);
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(CreateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            output_port.on_failure(CreateFailure::Error(Error::new("Record not found".to_string())));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(CreateFailure::Error(Error::new(record_invalid.to_string())));
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
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct OkGateway {
        entity: FertilizeEntity,
    }

    impl FertilizeGateway for OkGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
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
        success: Option<FertilizeEntity>,
        failure: Option<CreateFailure>,
    }

    impl FertilizeCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FertilizeEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_entity() -> FertilizeEntity {
        FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(1),
            user_id: Some(1),
            name: "Test".into(),
            n: Some(10.0),
            p: Some(5.0),
            k: Some(3.0),
            description: None,
            package_size: None,
            region: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    // Ruby: test "creates fertilize for a regular user and passes the entity to on_success"
    #[test]
    fn creates_for_regular_user() {
        let entity = sample_entity();
        let gateway = OkGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            name: "Test".into(),
            n: Some(10.0),
            p: Some(5.0),
            k: Some(3.0),
            region: Some("Kyoto".into()),
            ..FertilizeCreateInput::new("Test")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_some());
        assert!(output.failure.is_none());
    }

    // Ruby: test "rejects a reference fertilize requested by a non-admin user"
    #[test]
    fn rejects_reference_for_non_admin() {
        let gateway = OkGateway {
            entity: sample_entity(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            is_reference: Some(true),
            ..FertilizeCreateInput::new("Reference")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_none());
        match output.failure {
            Some(CreateFailure::Error(e)) => {
                assert_eq!(e.message, "t:fertilizes.flash.reference_only_admin");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
}
