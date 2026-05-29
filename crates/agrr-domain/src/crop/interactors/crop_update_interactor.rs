//! Ruby: `Domain::Crop::Interactors::CropUpdateInteractor`

use crate::crop::dtos::CropUpdateInput;
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct CropUpdateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CropUpdateInteractor<'a, G, O, U, T>
where
    G: CropGateway,
    O: CropUpdateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, translator: &'a T, user_lookup: &'a U) -> Self {
        Self { output_port, gateway, user_id, translator, user_lookup }
    }

    pub fn call(&mut self, input: CropUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(input.crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) = reference_record_authorization::assert_edit_allowed(&access_filter, &current) {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(());
        }

        if let Some(is_reference) = input.is_reference {
            if !reference_flag_change_allowed(&user, is_reference, current.reference()) {
                let message = self.translator.t("crops.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::ReferenceFlagChangeDenied(
                    ReferenceFlagChangeDeniedFailure::new(message, input.crop_id),
                ));
                return Ok(());
            }
        }

        let mut attrs = AttrMap::new();
        if let Some(name) = input.name { attrs.insert("name".into(), AttrValue::from(name.as_str())); }
        if let Some(variety) = input.variety { attrs.insert("variety".into(), AttrValue::from(variety.as_str())); }
        if let Some(v) = input.area_per_unit { attrs.insert("area_per_unit".into(), AttrValue::Str(v.to_string())); }
        if let Some(v) = input.revenue_per_area { attrs.insert("revenue_per_area".into(), AttrValue::Str(v.to_string())); }
        if let Some(region) = input.region { attrs.insert("region".into(), AttrValue::from(region.as_str())); }
        if let Some(groups) = input.groups {
            attrs.insert(
                "groups".into(),
                AttrValue::Str(
                    serde_json::to_string(&groups).unwrap_or_else(|_| "[]".to_string()),
                ),
            );
        }
        if let Some(is_reference) = input.is_reference { attrs.insert("is_reference".into(), AttrValue::Bool(is_reference)); }

        let normalized = crop_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );
        let effective_reference = normalized.get("is_reference").map(cast_boolean_attr).unwrap_or(current.reference());
        let effective_user_id = normalized.get("user_id").map(|v| match v {
            AttrValue::Int(id) => Some(*id),
            AttrValue::Null => None,
            _ => current.user_id,
        }).unwrap_or(current.user_id);

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t("activerecord.errors.models.crop.attributes.user.blank", &opts);
            self.output_port.on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.update_for_user(&user, input.crop_id, normalized) {
            Ok(entity) => { self.output_port.on_success(entity); Ok(()) }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(record_invalid.to_string())));
                    Ok(())
                }
                Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_update_interactor_test.rs"));
}
