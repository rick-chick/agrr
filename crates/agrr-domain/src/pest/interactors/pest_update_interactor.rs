//! Ruby: `Domain::Pest::Interactors::PestUpdateInteractor`

use crate::pest::dtos::PestUpdateInput;
use crate::pest::entities::PestEntity;
use crate::pest::gateways::{CropGateway, CropPestGateway, PestGateway};
use crate::pest::ports::{PestUpdateOutputPort, UpdateFailure};
use crate::pest::services::{CropPestAssociationSync, FilterAssociableCropIds};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct PestUpdateInteractor<'a, G, CG, CPG, O, U, T, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    crop_gateway: &'a CG,
    crop_pest_gateway: &'a CPG,
    user_id: i64,
    logger: &'a L,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, CG, CPG, O, U, T, L> PestUpdateInteractor<'a, G, CG, CPG, O, U, T, L>
where
    G: PestGateway,
    CG: CropGateway,
    CPG: CropPestGateway,
    O: PestUpdateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        crop_gateway: &'a CG,
        crop_pest_gateway: &'a CPG,
        logger: &'a L,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            crop_gateway,
            crop_pest_gateway,
            user_id,
            logger,
            translator,
            user_lookup,
        }
    }

    pub fn call(&mut self, input: PestUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pest_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(input.pest_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(UpdateFailure::Error(Error::new(message)));
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

        let mut attrs = AttrMap::new();
        if let Some(name) = input.name {
            attrs.insert("name".into(), AttrValue::from(name.as_str()));
        }
        if let Some(v) = input.name_scientific {
            attrs.insert("name_scientific".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.family {
            attrs.insert("family".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.order {
            attrs.insert("order".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.occurrence_season {
            attrs.insert("occurrence_season".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }

        if let Some(is_reference) = input.is_reference {
            if !reference_flag_change_allowed(&user, is_reference, current.reference()) {
                let message = self
                    .translator
                    .t("pests.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::ReferenceFlagChange(
                    ReferenceFlagChangeDeniedFailure::new(message, input.pest_id),
                ));
                return Ok(());
            }
            attrs.insert("is_reference".into(), AttrValue::Bool(is_reference));
        }

        let normalized = pest_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );
        let effective_reference = normalized
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(current.reference());
        let effective_user_id = normalized
            .get("user_id")
            .map(|v| match v {
                AttrValue::Int(id) => Some(*id),
                AttrValue::Null => None,
                _ => current.user_id,
            })
            .unwrap_or(current.user_id);

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.pest.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(());
        }

        let pest_entity = match self.gateway.update_for_user(&user, input.pest_id, normalized) {
            Ok(entity) => entity,
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(
                        record_invalid.to_string(),
                    )));
                    return Ok(());
                }
                Err(err) => return Err(err),
            },
        };

        if let Some(crop_ids) = input.crop_ids {
            let crop_ids = FilterAssociableCropIds::for_pest_update(
                &crop_ids,
                &pest_entity,
                &user,
                self.crop_gateway,
            )?;
            CropPestAssociationSync::new(self.crop_pest_gateway)
                .replace_all(pest_entity.id, &crop_ids)?;
        }

        self.logger.info(&format!(
            "PestUpdateInteractor: on_success called with pest_entity.id = {}",
            pest_entity.id
        ));
        self.output_port.on_success(pest_entity);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_pest_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_update_interactor_test.rs"));
}
