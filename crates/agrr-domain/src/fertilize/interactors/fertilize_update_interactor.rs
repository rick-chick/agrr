//! Ruby: `Domain::Fertilize::Interactors::FertilizeUpdateInteractor`

use crate::fertilize::dtos::{FertilizeUpdateFailure, FertilizeUpdateInput};
use crate::fertilize::entities::FertilizeEntity;
use crate::fertilize::gateways::FertilizeGateway;
use crate::fertilize::ports::{FertilizeUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::hash::blank_attr;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct FertilizeUpdateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeUpdateInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeUpdateOutputPort,
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
        input: FertilizeUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = fertilize_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(input.fertilize_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port.on_failure(UpdateFailure::Fertilize(
                        FertilizeUpdateFailure::new(err.to_string(), Some(input.fertilize_id)),
                    ));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(());
        }

        if let Some(is_reference) = input.is_reference {
            if !reference_flag_change_allowed(&user, is_reference, current.reference()) {
                let message = self
                    .translator
                    .t("fertilizes.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::Fertilize(
                    FertilizeUpdateFailure::new(message, Some(current.id.unwrap_or(input.fertilize_id))),
                ));
                return Ok(());
            }
        }

        let mut attrs = AttrMap::new();
        if let Some(ref name) = input.name {
            if !blank_attr(&AttrValue::Str(name.clone())) {
                attrs.insert("name".into(), AttrValue::from(name.as_str()));
            }
        }
        if let Some(v) = input.n {
            attrs.insert("n".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = input.p {
            attrs.insert("p".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = input.k {
            attrs.insert("k".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.package_size {
            attrs.insert("package_size".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.is_reference {
            attrs.insert("is_reference".into(), AttrValue::Bool(v));
        }

        let normalized = fertilize_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );

        let effective_reference = normalized
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(current.reference());
        let effective_user_id = match normalized.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) => None,
            _ => current.user_id,
        };

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.fertilize.attributes.user.blank",
                &opts,
            );
            self.output_port.on_failure(UpdateFailure::Fertilize(
                FertilizeUpdateFailure::new(message, current.id),
            ));
            return Ok(());
        }

        match self
            .gateway
            .update_for_user(&user, input.fertilize_id, normalized)
        {
            Ok(entity) => {
                self.output_port.on_success(entity);
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(
                &mut self.output_port,
                err,
                current.id.or(Some(input.fertilize_id)),
            ),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
        fertilize_id: Option<i64>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(UpdateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            output_port.on_failure(UpdateFailure::Fertilize(FertilizeUpdateFailure::new(
                "Record not found".to_string(),
                fertilize_id,
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(UpdateFailure::Fertilize(FertilizeUpdateFailure::new(
                    record_invalid.to_string(),
                    fertilize_id,
                )));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_fertilize_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/fertilize/interactors_fertilize_update_interactor_test.rs"));
}
