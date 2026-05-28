//! Ruby: `Domain::Pesticide::Interactors::PesticideCreateInteractor`

use crate::pesticide::dtos::PesticideCreateInput;
use crate::pesticide::entities::PesticideEntity;
use crate::pesticide::gateways::PesticideGateway;
use crate::pesticide::ports::{CreateFailure, PesticideCreateOutputPort};
use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_assignment_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::type_converters::cast_boolean_attr;

pub struct PesticideCreateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PesticideCreateInteractor<'a, G, O, U, T>
where
    G: PesticideGateway,
    O: PesticideCreateOutputPort,
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
        input: PesticideCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();
        let is_reference = input.is_reference.unwrap_or(false);

        if !reference_assignment_allowed(&user, is_reference) {
            let message = self
                .translator
                .t("pesticides.flash.reference_only_admin", &opts);
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        let mut attrs = AttrMap::new();
        attrs.insert("name".into(), AttrValue::from(input.name.as_str()));
        if let Some(v) = input.active_ingredient {
            attrs.insert("active_ingredient".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.crop_id {
            attrs.insert("crop_id".into(), AttrValue::Int(v));
        }
        if let Some(v) = input.pest_id {
            attrs.insert("pest_id".into(), AttrValue::Int(v));
        }
        if let Some(v) = input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }
        attrs.insert("is_reference".into(), AttrValue::Bool(is_reference));

        let attrs = pesticide_policy::normalize_attrs_for_create(&user, attrs);

        let effective_reference = attrs
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(false);
        let effective_user_id = match attrs.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) | None => None,
            _ => None,
        };

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.pesticide.attributes.user.blank",
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
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct PolicyDeniedGateway;
    impl PesticideGateway for PolicyDeniedGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
            _: AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(PolicyPermissionDenied))
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
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
        success: Option<PesticideEntity>,
        failure: Option<CreateFailure>,
    }

    impl PesticideCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: PesticideEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_entity() -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id: 1,
            user_id: Some(10),
            name: "X".into(),
            active_ingredient: None,
            description: None,
            crop_id: Some(1),
            pest_id: Some(2),
            region: None,
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid")
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let gateway = PolicyDeniedGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideCreateInput {
            name: "X".into(),
            crop_id: Some(1),
            pest_id: Some(2),
            ..PesticideCreateInput::new("X")
        };
        interactor.call(input).expect("handled");
        assert!(matches!(
            output.failure,
            Some(CreateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "calls on_failure with Error when non-admin requests reference pesticide"
    #[test]
    fn calls_on_failure_when_non_admin_requests_reference_pesticide() {
        struct NeverCalledGateway;
        impl PesticideGateway for NeverCalledGateway {
            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
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
                _: AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(sample_entity())
            }
            fn update_for_user(
                &self,
                _: &User,
                _: i64,
                _: AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &dyn TranslatorPort,
            ) -> Result<
                crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn list_by_crop_id_for_filter(
                &self,
                _: i64,
                _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
            ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
        }

        let gateway = NeverCalledGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideCreateInput {
            name: "参照農薬".into(),
            active_ingredient: Some("X".into()),
            crop_id: Some(1),
            pest_id: Some(2),
            is_reference: Some(true),
            ..PesticideCreateInput::new("参照農薬")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_none());
        match output.failure {
            Some(CreateFailure::Error(e)) => {
                assert_eq!(e.message, "t:pesticides.flash.reference_only_admin");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
}
