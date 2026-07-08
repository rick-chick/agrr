//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor`

use crate::agricultural_task::dtos::AgriculturalTaskUpdateInput;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::agricultural_task::interactors::attr_helpers::str_present;
use crate::agricultural_task::ports::{AgriculturalTaskUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::agricultural_task_policy;
use crate::shared::policies::referencable_resource_policy::{
    duplicate_name_record, reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct AgriculturalTaskUpdateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> AgriculturalTaskUpdateInteractor<'a, G, O, U, T>
where
    G: AgriculturalTaskGateway,
    O: AgriculturalTaskUpdateOutputPort,
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
        update_input: AgriculturalTaskUpdateInput,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = agricultural_task_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(update_input.id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port
                        .on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(false);
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(false);
        }

        if let Some(requested_ref) = update_input.is_reference {
            let requested = requested_ref;
            if !reference_flag_change_allowed(&user, requested, current.reference()) {
                let message = self
                    .translator
                    .t("agricultural_tasks.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::ReferenceFlag(
                    ReferenceFlagChangeDeniedFailure::new(message, update_input.id),
                ));
                return Ok(false);
            }
        }

        let mut attrs = AttrMap::new();
        if str_present(&update_input.name) {
            if let Some(name) = update_input.name {
                attrs.insert("name".into(), AttrValue::from(name.as_str()));
            }
        }
        if let Some(v) = update_input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.time_per_sqm {
            attrs.insert("time_per_sqm".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = update_input.weather_dependency {
            attrs.insert("weather_dependency".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.required_tools {
            attrs.insert("required_tools".into(), AttrValue::Str(v.join(",")));
        }
        if let Some(v) = update_input.skill_level {
            attrs.insert("skill_level".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.task_type {
            attrs.insert("task_type".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.is_reference {
            attrs.insert("is_reference".into(), AttrValue::Bool(v));
        }

        let normalized = agricultural_task_policy::normalize_attrs_for_update(
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
                "activerecord.errors.models.agricultural_task.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(false);
        }

        if normalized.contains_key("name") {
            let name = normalized
                .get("name")
                .and_then(|v| match v {
                    AttrValue::Str(s) => Some(s.as_str()),
                    _ => None,
                })
                .unwrap_or("");
            let existing = self.find_existing_by_name(effective_reference, effective_user_id, name)?;
            if duplicate_name_record(existing.and_then(|e| e.id), Some(update_input.id)) {
                let message = self.translator.t(
                    "activerecord.errors.models.agricultural_task.attributes.name.taken",
                    &opts,
                );
                self.output_port
                    .on_failure(UpdateFailure::Error(Error::new(message)));
                return Ok(false);
            }
        }

        let task_entity = self.gateway.within_transaction(|| {
            self.gateway.update(update_input.id, normalized)
        })?;

        self.output_port.on_success(task_entity);
        Ok(true)
    }

    fn find_existing_by_name(
        &self,
        is_reference: bool,
        user_id: Option<i64>,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if is_reference {
            self.gateway.find_by_reference_and_name(name)
        } else {
            self.gateway
                .find_by_user_id_and_name(user_id.unwrap_or(self.user_id), name)
        }
    }
}

#[cfg(test)]
mod interactors_agricultural_task_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/interactors_agricultural_task_update_interactor_test.rs"));
}
